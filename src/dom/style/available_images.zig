//! HTML §4.8.4.3.3: a Document's list of available images.
//!
//! This contains completed images, never pending requests. Its key is not
//! the CSS resource-fetch key. Entries created by this document have the
//! ignore-higher-layer-caching flag set (update-image-data step 27).
//! Nothing copies entries across documents or clears that flag here.
const std = @import("std");
const platform = @import("platform");
const fetch = @import("fetch");
const mimesniff = @import("mimesniff");
const origin_record = @import("../origin_record.zig");
const Allocator = std.mem.Allocator;

/// Crane's existing per-image limits (platform decision 19): 32768 pixels
/// a side and 2^26 pixels (256 MiB RGBA8).
const image_limits: platform.ImageLimits = .{ .max_dimension = 1 << 15, .max_pixels = 1 << 26 };

/// HTML image request data, through MIME Sniffing and the platform decoder.
/// Status codes do not decide image validity. AsyncFetch's unfiltered body
/// remains usable by a no-CORS image; its opaque type preserves canvas taint.
pub fn decodeResponse(allocator: Allocator, response: *const fetch.internal.InternalResponse) ?*Image {
    if (response.response_type == .@"error") return null;
    const body = response.body orelse return null;
    const cors_same_origin = response.response_type != .@"opaque" and response.response_type != .opaqueredirect;
    return decodeBody(allocator, &response.header_list, body.getBytes(), cors_same_origin);
}

pub fn decodeBody(allocator: Allocator, headers: *const fetch.internal.HeaderList, body: []const u8, cors_same_origin: bool) ?*Image {
    if (platform.capabilities.image_decoding == .unsupported) return null;
    var supplied = fetch.internal.mime.extractMimeType(allocator, headers) catch return null;
    defer if (supplied) |*mime| mime.deinit();
    // MIME Sniffing §5.2: inspect at most the resource header (1445 bytes).
    const header = body[0..@min(body.len, 1445)];
    var computed = (mimesniff.sniffInImageContext(allocator, supplied, header) catch return null) orelse return null;
    defer computed.deinit();
    const mime = mimesniff.serializeMimeTypeToBytes(allocator, computed) catch return null;
    defer allocator.free(mime);
    // HTML update-image-data step 27: dimensions obtained means an image,
    // including a partial decode; see Image.decodingFails for decode().
    const decoded = platform.decodeImage(allocator, platform.Str.from(mime), platform.Bytes.from(body), image_limits) catch return null;
    return Image.create(allocator, .{
        .width = decoded.width,
        .height = decoded.height,
        .pixels = @constCast(decoded.pixels.slice()),
        .cors_same_origin = cors_same_origin,
        .status = decoded.status,
        .empty = decoded.empty,
    }) catch {
        allocator.free(decoded.pixels.slice());
        return null;
    };
}

/// Decoded RGBA8, owned jointly by requests and the document cache. The
/// uncached path adopts the platform allocation; it makes no pixel copy.
pub const Image = struct {
    allocator: Allocator,
    refs: usize = 1,
    width: u32,
    height: u32,
    pixels: []u8,
    cors_same_origin: bool,
    status: platform.ImageDecodeStatus,
    empty: bool,

    pub const Data = struct {
        width: u32,
        height: u32,
        pixels: []u8,
        cors_same_origin: bool,
        status: platform.ImageDecodeStatus = .complete,
        empty: bool = false,
    };

    /// Takes ownership of pixels on SUCCESS only, as the platform decoder
    /// does. The caller frees them if allocating the header fails.
    pub fn create(allocator: Allocator, data: Data) Allocator.Error!*Image {
        const self = try allocator.create(Image);
        self.* = .{
            .allocator = allocator,
            .width = data.width,
            .height = data.height,
            .pixels = data.pixels,
            .cors_same_origin = data.cors_same_origin,
            .status = data.status,
            .empty = data.empty,
        };
        return self;
    }

    pub fn retain(self: *Image) *Image {
        std.debug.assert(self.refs != 0);
        self.refs += 1;
        return self;
    }

    pub fn release(self: *Image) void {
        std.debug.assert(self.refs != 0);
        self.refs -= 1;
        if (self.refs != 0) return;
        self.allocator.free(self.pixels);
        self.allocator.destroy(self);
    }

    /// Preserve HTMLImageElement's browser-tested partial-image contract:
    /// a truncated image with dimensions is available. Corruption that
    /// decoded no pixels makes decode() fail (lane imgpart, 2026-10-12).
    pub fn decodingFails(self: *const Image) bool {
        return self.status == .corrupt and self.empty;
    }
};

pub const CorsSetting = enum {
    none,
    anonymous,
    use_credentials,

    pub fn fromAttribute(value: ?[]const u8) CorsSetting {
        const text = value orelse return .none;
        return if (std.ascii.eqlIgnoreCase(text, "use-credentials")) .use_credentials else .anonymous;
    }
};

pub const Key = struct {
    url: []const u8,
    cors: CorsSetting = .none,
    /// Borrowed when looking up; cache entries retain it. A resolved
    /// OriginRecord preserves opaque identity; "null" strings cannot.
    origin: ?*origin_record.OriginRecord = null,

    pub fn eql(a: Key, b: Key) bool {
        if (a.cors != b.cors or !std.mem.eql(u8, a.url, b.url)) return false;
        if (a.cors == .none) return true;
        const left = a.origin orelse return false;
        const right = b.origin orelse return false;
        return origin_record.sameOrigin(.{ .serialized = left.serialized orelse "null", .record = left }, .{ .serialized = right.serialized orelse "null", .record = right });
    }

    fn owned(self: Key, allocator: Allocator) Allocator.Error!Key {
        const url = try allocator.dupe(u8, self.url);
        return .{ .url = url, .cors = self.cors, .origin = if (self.cors != .none) self.origin.?.retain() else null };
    }

    fn deinit(self: Key, allocator: Allocator) void {
        allocator.free(self.url);
        if (self.origin) |origin| origin.release();
    }
};

const KeyContext = struct {
    pub fn hash(_: KeyContext, key: Key) u64 {
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHash(&hasher, key.url.len);
        hasher.update(key.url);
        std.hash.autoHash(&hasher, key.cors);
        if (key.cors != .none) {
            const origin = key.origin orelse return hasher.final();
            const serialized = origin.serialized orelse "null";
            if (std.mem.eql(u8, serialized, "null")) {
                std.hash.autoHash(&hasher, @intFromPtr(origin));
            } else hasher.update(serialized);
        }
        return hasher.final();
    }

    pub fn eql(_: KeyContext, a: Key, b: Key) bool {
        return a.eql(b);
    }
};

pub const Cache = struct {
    allocator: Allocator,
    entries: std.HashMapUnmanaged(Key, *Image, KeyContext, 80) = .empty,

    pub fn init(allocator: Allocator) Cache {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Cache) void {
        self.clear();
        self.entries.deinit(self.allocator);
    }

    pub fn clear(self: *Cache) void {
        var iterator = self.entries.iterator();
        while (iterator.next()) |entry| {
            entry.key_ptr.deinit(self.allocator);
            entry.value_ptr.*.release();
        }
        self.entries.clearRetainingCapacity();
    }

    /// Borrowed until a cache mutation; a request retaining the image must
    /// take its own reference before releasing/replacing its old image.
    pub fn get(self: *Cache, key: Key) ?*Image {
        return self.entries.get(key);
    }

    /// HTML update-image-data step 27: the fully available image is added
    /// with ignore-higher-layer-caching SET. The caller keeps its reference.
    pub fn put(self: *Cache, key: Key, image: *Image) Allocator.Error!void {
        if (self.entries.getPtr(key)) |existing| {
            const replacement = image.retain();
            existing.*.release();
            existing.* = replacement;
            return;
        }
        const owned_key = try key.owned(self.allocator);
        errdefer owned_key.deinit(self.allocator);
        try self.entries.putNoClobber(self.allocator, owned_key, image);
        _ = image.retain();
    }
};

const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const document_activity = @import("../document_activity.zig");
const document_lifecycle = @import("../document_lifecycle.zig");
const same_object = @import("../same_object_cache.zig");

/// A non-img image resource (HTML image button, SVG image). The owning
/// element holds one native reference. A fetch and each queued delivery own
/// separate references, so teardown can cancel without freeing a queued
/// task's context. Pending activity keeps the element through its event.
pub const Loader = struct {
    allocator: Allocator,
    refs: usize = 1,
    element: *runtime.Instance,
    element_generation: u64,
    realm: runtime.Context,
    attached: bool = true,
    generation: u64 = 0,
    handle: ?*fetch.algorithms.AsyncFetch = null,
    kept: bool = false,
    pending: bool = false,
    abort_marked: ?u64 = null,
    document: ?*runtime.Instance = null,
    document_generation: u64 = 0,
    document_realm: ?runtime.Context = null,
    delaying_load: bool = false,
    image: ?*Image = null,

    pub const Options = struct {
        initiator: fetch.internal.InitiatorType,
        cors: CorsSetting = .none,
        referrer_policy: fetch.internal.ReferrerPolicy = .empty,
        /// HTML image buttons return without replacing their image for an
        /// empty or unparsable src. SVG ImageLoader replaces it and reports
        /// an asynchronous error (SVG 2 §16.1.7 invalid references).
        invalid_source: enum { ignore, queue_error } = .ignore,
    };

    pub fn create(element: *runtime.Instance) Allocator.Error!*Loader {
        const allocator = element.ctx.allocator;
        const self = try allocator.create(Loader);
        self.* = .{
            .allocator = allocator,
            .element = element,
            .element_generation = runtime.SlabAllocator.generationOf(element),
            .realm = element.ctx,
        };
        return self;
    }

    fn retain(self: *Loader) void {
        std.debug.assert(self.refs != 0);
        self.refs += 1;
    }

    fn release(self: *Loader) void {
        std.debug.assert(self.refs != 0);
        self.refs -= 1;
        if (self.refs != 0) return;
        std.debug.assert(self.handle == null and !self.kept);
        if (self.image) |image| image.release();
        self.allocator.destroy(self);
    }

    /// The owner has detached its pointer before calling destroy.
    pub fn destroy(self: *Loader) void {
        self.cancel();
        self.attached = false;
        self.release();
    }

    fn ownerLive(self: *const Loader) bool {
        // Realm first: its teardown may already have freed the slab ledger.
        return self.attached and self.realm.hasEngine() and
            runtime.SlabAllocator.generationOf(self.element) == self.element_generation;
    }

    fn documentLive(self: *const Loader) bool {
        const realm = self.document_realm orelse return false;
        if (!realm.hasEngine()) return false;
        const document = self.document orelse return false;
        return runtime.SlabAllocator.generationOf(document) == self.document_generation;
    }

    /// Cancel the transport and invalidate queued delivery before ending the
    /// native keep. No script runs on abort/destruction (HTML abort step 2).
    pub fn cancel(self: *Loader) void {
        self.generation +%= 1;
        self.abort_marked = null;
        if (self.handle) |handle| {
            self.handle = null;
            handle.terminate();
            self.release(); // the transport's reference; terminate has no callbacks
        }
        self.finishPending();
    }

    fn finishPending(self: *Loader) void {
        self.pending = false;
        if (self.delaying_load) {
            self.delaying_load = false;
            if (self.documentLive()) document_lifecycle.undelayLoadEvent(self.document.?);
        }
        if (self.kept) {
            self.kept = false;
            if (self.ownerLive()) engine.releasePlatformObject(self.element);
        }
    }

    pub fn belongsTo(self: *const Loader, document: *runtime.Instance) bool {
        return self.document == document and self.documentLive();
    }

    pub fn markAbort(self: *Loader, document: *runtime.Instance) bool {
        if (!self.pending or !self.belongsTo(document)) return false;
        self.abort_marked = self.generation;
        return true;
    }

    pub fn abortMarked(self: *Loader, document: *runtime.Instance) void {
        const marked = self.abort_marked orelse return;
        if (marked == self.generation and self.belongsTo(document)) self.cancel();
    }

    /// HTML §4.10.5.1.19 steps 1–4 / SVG 2 image fetching. The caller's
    /// trigger rules decide whether to replace a prior request.
    pub fn start(self: *Loader, input: []const u8, options: Options) !void {
        if (!self.ownerLive()) return;
        const empty = if (options.invalid_source == .queue_error)
            std.mem.trim(u8, input, " \t\n\r\x0c").len == 0
        else
            input.len == 0;
        if (empty and options.invalid_source == .ignore) return;
        const document = (try interfaces.Node.get_ownerDocument(self.element)) orelse return;
        const document_generation = runtime.SlabAllocator.generationOf(document);
        if (!document.ctx.hasEngine() or document_activity.activity(document, document_generation) == .gone) return;
        const global = (try interfaces.Document.get_defaultView(document)) orelse return;
        const parsed = if (empty) null else try @import("../encoding_parse.zig").encodingParseAndSerialize(self.element, input);
        const url = parsed orelse {
            if (options.invalid_source == .queue_error) {
                self.beginPending(document);
                if (self.image) |old| old.release();
                self.image = null;
                self.queueOutcome(null);
            }
            return;
        };
        defer self.allocator.free(url);
        const request = try fetch.internal.InternalRequest.init(self.allocator, url);
        var request_owned = true;
        defer if (request_owned) request.deinit();
        request.destination = .image;
        request.initiator_type = options.initiator;
        request.mode = if (options.cors == .none) .no_cors else .cors;
        request.credentials_mode = if (options.cors == .anonymous) .same_origin else .include;
        request.use_url_credentials = true;
        request.referrer_policy = options.referrer_policy;
        var client = try @import("../global_settings.zig").requestClient(global);
        defer client.deinit();
        try fetch.internal.populateRequestFromClient(request, client.request);

        self.beginPending(document);
        self.retain(); // the transport, through finished/gone or explicit cancellation
        request_owned = false;
        self.handle = fetch.algorithms.AsyncFetch.start(self.allocator, request, .{}, @import("../agent_fetches.zig").of(self.realm), .{
            .context = self,
            .done = done,
            .alive = alive,
            .gone = gone,
            .finished = finished,
        }) catch |err| {
            self.release();
            self.queueOutcome(null);
            return err;
        };
    }

    /// Both a transport completion and an invalid SVG reference deliver a
    /// task. Keep the element and its load delay until that delivery ends.
    fn beginPending(self: *Loader, document: *runtime.Instance) void {
        self.cancel();
        self.document = document;
        self.document_generation = runtime.SlabAllocator.generationOf(document);
        self.document_realm = document.ctx;
        self.pending = true;
        self.kept = true;
        engine.keepPlatformObjectAlive(self.element);
        self.delaying_load = true;
        document_lifecycle.delayLoadEvent(document);
    }

    fn alive(context: *anyopaque) bool {
        const self: *Loader = @ptrCast(@alignCast(context));
        return self.ownerLive() and self.documentLive() and
            document_activity.activity(self.document.?, self.document_generation) != .gone;
    }

    fn gone(context: *anyopaque) void {
        const self: *Loader = @ptrCast(@alignCast(context));
        self.handle = null;
        self.generation +%= 1;
        self.finishPending();
        self.release();
    }

    fn finished(context: *anyopaque) void {
        const self: *Loader = @ptrCast(@alignCast(context));
        self.handle = null;
        self.release();
    }

    fn done(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        const self: *Loader = @ptrCast(@alignCast(context));
        var decoded: ?*Image = null;
        if (outcome) |result| {
            var owned = result;
            defer owned.deinit();
            if (self.ownerLive()) decoded = decodeResponse(self.allocator, result.response);
        } else |_| {}
        if (!self.ownerLive()) {
            if (decoded) |image| image.release();
            return;
        }
        self.queueOutcome(decoded);
    }

    fn queueOutcome(self: *Loader, image: ?*Image) void {
        const loop = self.realm.getOptionalEventLoop() orelse {
            if (image) |value| value.release();
            self.finishPending();
            return;
        };
        const delivery = self.allocator.create(Delivery) catch {
            if (image) |value| value.release();
            self.finishPending();
            return;
        };
        self.retain();
        delivery.* = .{ .loader = self, .generation = self.generation, .image = image };
        // HTML image buttons: user interaction task source. SVG image
        // completion: networking. The live Browser queue currently has one
        // FIFO; html/event_loop/task.zig's source enum is not wired to it
        // (liaison Q15, source-aware queue is an engine follow-up).
        loop.queueTask(.{
            .callback = Delivery.run,
            .context = delivery,
            .drop = Delivery.drop,
            .document = self.document,
            .document_generation = self.document_generation,
        });
    }

    const Delivery = struct {
        loader: *Loader,
        generation: u64,
        image: ?*Image,

        fn current(self: *const Delivery) bool {
            return self.loader.ownerLive() and self.loader.generation == self.generation;
        }

        fn deinit(self: *Delivery) void {
            const loader = self.loader;
            if (self.image) |image| image.release();
            loader.allocator.destroy(self);
            loader.release();
        }

        fn drop(context: ?*anyopaque) void {
            const self: *Delivery = @ptrCast(@alignCast(context.?));
            defer self.deinit();
            if (self.current()) self.loader.finishPending();
        }

        fn run(context: ?*anyopaque) void {
            const self: *Delivery = @ptrCast(@alignCast(context.?));
            defer self.deinit();
            if (!self.current()) return;
            defer if (self.current()) self.loader.finishPending();
            if (self.loader.image) |old| old.release();
            self.loader.image = if (self.image) |image| image.retain() else null;
            engine.runTaskInRealm(self.loader.realm, steps, self) catch {};
        }

        fn steps(context: ?*anyopaque) void {
            const self: *Delivery = @ptrCast(@alignCast(context.?));
            if (!self.current()) return;
            const element = self.loader.element;
            const event = interfaces.Event.call_constructor(element.ctx, runtime.DOMString.initInterned(if (self.image != null) "load" else "error"), webidl.Opt(@import("dictionaries").EventInit).notPassed()) catch return;
            const generation = runtime.SlabAllocator.generationOf(event);
            defer event.releaseIfUnwrapped(generation);
            _ = @import("../fire_event.zig").dispatchTrusted(element, event) catch {};
        }
    };
};
