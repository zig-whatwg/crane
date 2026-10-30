//! SVG 2 §16.1.7: resource-reference plumbing shared by the SVG owners.
//! The owners install their state accessors; no helper names an impl.
const std = @import("std");
const runtime = @import("runtime");
const element_data = @import("../element_data.zig");
const attribute_steps = @import("../attribute_change_steps.zig");
const hooks = @import("hooks.zig");

pub const svg_namespace = "http://www.w3.org/2000/svg";
pub const xlink_namespace = "http://www.w3.org/1999/xlink";

/// Called by both owners at process start: the existing registry makes
/// installing this same namespace-wide step idempotent.
pub fn installAttributeSteps() void {
    attribute_steps.installForAttribute(svg_namespace, "href", .{ .change = attributeChanged });
    attribute_steps.installForAttribute(svg_namespace, "crossorigin", .{ .change = attributeChanged });
}

/// SVG 2 §16.1.2: an unnamespaced href takes precedence over xlink:href,
/// even when its value is empty. This borrows only until the next mutation.
pub fn href(element: *runtime.Instance) ?[]const u8 {
    const data = element_data.of(element) orelse return null;
    if (data.findAttribute(null, "href")) |attribute| return attribute.value;
    if (data.findAttribute(xlink_namespace, "href")) |attribute| return attribute.value;
    return null;
}

fn attributeChanged(element: *runtime.Instance, local_name: []const u8, _: ?[]const u8, _: ?[]const u8, namespace: ?[]const u8) void {
    const data = element_data.of(element) orelse return;
    if (namespace) |ns| {
        if (!std.mem.eql(u8, local_name, "href") or !std.mem.eql(u8, ns, xlink_namespace)) return;
        if (data.findAttribute(null, "href") != null) return;
    }
    const name = data.local_name.asSlice();
    if (std.mem.eql(u8, name, "image")) hooks.svgImageResourceChanged(element) else if (std.mem.eql(u8, name, "use")) hooks.svgUseResourceChanged(element);
}

const Allocator = std.mem.Allocator;
const interfaces = @import("interfaces");
const engine = @import("engine");
const fetch = @import("fetch");
const webidl = @import("webidl");
const lifecycle = @import("../document_lifecycle.zig");
const resource_loading = @import("resource_loading.zig");
const RequestKey = resource_loading.RequestKey;

/// SVG 2 §16.1.7.5. This checks reference validity, not the rendering of
/// a use shadow tree (that separate prerequisite is liaison Q11).
pub const TargetKind = enum { use, paint, marker, clip_path, mask, filter, image };

pub fn targetAllowed(namespace: ?[]const u8, name: []const u8, kind: TargetKind) bool {
    if (!std.mem.eql(u8, namespace orelse "", svg_namespace)) return false;
    return switch (kind) {
        .use => true,
        .paint => std.mem.eql(u8, name, "linearGradient") or std.mem.eql(u8, name, "radialGradient") or std.mem.eql(u8, name, "pattern"),
        .marker => std.mem.eql(u8, name, "marker"),
        .clip_path => std.mem.eql(u8, name, "clipPath"),
        .mask => std.mem.eql(u8, name, "mask"),
        .filter => std.mem.eql(u8, name, "filter"),
        .image => std.mem.eql(u8, name, "svg"),
    };
}

fn filePart(url: []const u8) []const u8 {
    return url[0 .. std.mem.indexOfScalar(u8, url, '#') orelse url.len];
}

fn fragmentPart(url: []const u8) []const u8 {
    const mark = std.mem.indexOfScalar(u8, url, '#') orelse return "";
    return url[mark + 1 ..];
}

pub fn sameDocument(resolved_url: []const u8, base_url: []const u8) bool {
    return std.mem.eql(u8, filePart(resolved_url), filePart(base_url));
}

fn target(document: *runtime.Instance, fragment: []const u8, kind: TargetKind) ?*runtime.Instance {
    const element = if (fragment.len == 0)
        (interfaces.Document.get_documentElement(document) catch null) orelse return null
    else blk: {
        const bytes = document.ctx.allocator.dupe(u8, fragment) catch return null;
        defer document.ctx.allocator.free(bytes);
        const decoded = std.Uri.percentDecodeInPlace(bytes);
        break :blk (interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(decoded)) catch null) orelse return null;
    };
    const data = element_data.of(element) orelse return null;
    return if (targetAllowed(data.namespaceSlice(), data.local_name.asSlice(), kind)) element else null;
}

/// One immutable subresource document. The consuming Document traces the
/// parsed Document: neither the cache nor a pending callback is a GC root.
/// Like WebKit's CachedSVGDocument, clients observe one shared download.
pub const Resource = struct {
    allocator: Allocator,
    key: RequestKey,
    owner: *runtime.Instance,
    realm: runtime.Context,
    owner_generation: u64,
    handle: ?*fetch.algorithms.AsyncFetch = null,
    status: enum { pending, complete, failed } = .pending,
    parsed: ?*runtime.Instance = null,
    parsed_generation: u64 = 0,
    /// The resource's counted reference on its parsed document (refcount
    /// step 5i, H-RC8-SVG-DOC; WebKit's CachedSVGDocument keeps
    /// `RefPtr<SVGDocument> m_document`): it takes the document's born
    /// reference over at the parse, and lets go when the resource goes.
    /// Counted only: the owner's traced edge keeps the document from the
    /// collector until step 7.
    parsed_ref: @import("../node_holds.zig").CountedRef = .{},
    clients: std.ArrayList(*UseLoad) = .empty,
    abort_marked: bool = false,

    fn slot(self: *const Resource, buffer: []u8) engine.TracedSlot {
        return .{ .name = std.fmt.bufPrint(buffer, "CSSSVG:document:{x}", .{@intFromPtr(self)}) catch unreachable };
    }

    fn ownerLive(self: *const Resource) bool {
        return self.realm.hasEngine() and runtime.SlabAllocator.generationOf(self.owner) == self.owner_generation;
    }

    fn start(self: *Resource) !void {
        errdefer self.complete(false);
        const request = try fetch.internal.InternalRequest.init(self.allocator, self.key.url);
        var owned = true;
        defer if (owned) request.deinit();
        request.destination = .image;
        request.mode = self.key.mode;
        request.credentials_mode = self.key.credentials;
        request.referrer_policy = self.key.referrer_policy;
        request.initiator_type = if (self.key.origin_clean) .other else null;
        const window = (try interfaces.Document.get_defaultView(self.owner)) orelse return error.InvalidState;
        var client = try @import("../global_settings.zig").requestClient(window);
        defer client.deinit();
        try fetch.internal.populateRequestFromClient(request, client.request);
        // SVG style references use their external sheet's referrer/policy
        // (Chrome/Firefox); inline masks use the document's (Firefox/Safari).
        // Other inline SVG fetches split Chrome/Firefox on policy while
        // Safari does not fetch: the spec decides that tie, also document.
        // Thus all mechanisms follow Firefox (liaison Q29); aligned WPT
        // runs C5348835735109632/F5199781143248896/S5944045691207680.
        if (self.key.referrer) |referrer| try request.setReferrerUrl(referrer);
        owned = false;
        self.handle = try fetch.algorithms.AsyncFetch.start(self.allocator, request, .{}, @import("../agent_fetches.zig").of(self.realm), .{
            .context = self,
            .done = done,
            .alive = alive,
            .gone = gone,
            .finished = finished,
        });
    }

    fn alive(context: *anyopaque) bool {
        const self: *Resource = @ptrCast(@alignCast(context));
        return self.ownerLive() and @import("../document_activity.zig").activity(self.owner, self.owner_generation) != .gone;
    }

    fn gone(context: *anyopaque) void {
        const self: *Resource = @ptrCast(@alignCast(context));
        self.handle = null;
        self.cancelClients();
        self.status = .failed;
    }

    fn finished(context: *anyopaque) void {
        const self: *Resource = @ptrCast(@alignCast(context));
        self.handle = null;
    }

    fn done(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        const self: *Resource = @ptrCast(@alignCast(context));
        var result = outcome catch return self.complete(false);
        defer result.deinit();
        var parse_context = ParseContext{ .resource = self, .response = result.response };
        // The parser and wrapper tracing require the resource's realm,
        // without a script checkpoint inside Fetch's completion callback.
        engine.runInRealm(self.realm, ParseContext.run, &parse_context) catch {};
        self.complete(parse_context.valid);
    }

    const ParseContext = struct {
        resource: *Resource,
        response: *const fetch.internal.InternalResponse,
        valid: bool = false,

        fn run(context: ?*anyopaque) void {
            const self: *ParseContext = @ptrCast(@alignCast(context.?));
            self.valid = self.resource.parse(self.response) catch false;
        }
    };

    /// SVG 2 §16.1.7.3: parse an internal XML document in secure static
    /// mode. Its missing browsing context prevents every resource loader;
    /// the parser hook disables scripts, and nothing exposes the tree.
    fn parse(self: *Resource, response: *const fetch.internal.InternalResponse) !bool {
        if (!self.ownerLive() or response.response_type == .@"error" or !fetch.internal.isOkStatus(response.status)) return false;
        const body = response.body orelse return false;
        const bytes = body.getBytes();
        if (bytes.len == 0) return false;
        var mime = (try fetch.internal.mime.extractMimeType(self.allocator, &response.header_list)) orelse return false;
        defer mime.deinit();
        if (!@import("mimesniff").predicates.isXmlMimeType(&mime)) return false;
        const origin = try @import("../document_origin.zig").shareable(self.owner);
        const document = try interfaces.XMLDocument.initWith(self.allocator, self.realm, .{ .origin = origin, .ready_state = ._complete_ });
        var adopted = false;
        defer if (!adopted) @import("../node_creation.zig").destroyUninserted(document);
        const internals = @import("../document_internals.zig");
        try internals.setDocumentType(document, .xml);
        const content_type = response.header_list.getFirstValue("content-type") orelse "image/svg+xml";
        try internals.setContentType(document, content_type);
        try internals.setURL(document, response.url() orelse self.key.url);
        lifecycle.markReadyForPostLoadTasks(document);
        if (!try hooks.svgParseResourceDocument(document, bytes, content_type)) return false;
        var buffer: [64]u8 = undefined;
        @import("objects.zig").keepFrom(self.owner, document, self.slot(&buffer));
        self.parsed = document;
        self.parsed_generation = runtime.SlabAllocator.generationOf(document);
        const base = @import("../instance_bridge.zig").getNodeBase(@ptrCast(document));
        self.parsed_ref.take(document, base);
        if (base) |node| @import("../refcount.zig").takeOverCreatorReference(node);
        adopted = true;
        return true;
    }

    fn complete(self: *Resource, valid: bool) void {
        self.status = if (valid) .complete else .failed;
        while (self.clients.pop()) |client| {
            client.resource = null;
            client.deliver(valid and self.lookup(client.fragment, .use) != null);
        }
    }

    pub fn lookup(self: *const Resource, fragment: []const u8, kind: TargetKind) ?*runtime.Instance {
        if (!self.ownerLive()) return null;
        const document = self.parsed orelse return null;
        if (runtime.SlabAllocator.generationOf(document) != self.parsed_generation) return null;
        return target(document, fragment, kind);
    }

    fn removeClient(self: *Resource, client: *UseLoad) void {
        for (self.clients.items, 0..) |entry, i| if (entry == client) {
            _ = self.clients.swapRemove(i);
            return;
        };
    }

    fn cancelClients(self: *Resource) void {
        while (self.clients.pop()) |client| {
            client.resource = null;
            client.cancel();
        }
    }

    pub fn cancel(self: *Resource) void {
        self.abort_marked = false;
        if (self.handle) |handle| {
            self.handle = null;
            handle.terminate();
        }
        self.cancelClients();
        if (self.status == .pending) self.status = .failed;
    }

    fn destroy(self: *Resource) void {
        self.cancel();
        self.clients.deinit(self.allocator);
        if (self.parsed != null and self.ownerLive()) {
            var buffer: [64]u8 = undefined;
            engine.forgetTracedChild(self.owner, self.slot(&buffer));
        }
        if (self.parsed) |document| self.parsed_ref.release(document);
        self.key.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

pub const Cache = struct {
    allocator: Allocator,
    entries: std.HashMapUnmanaged(RequestKey, *Resource, resource_loading.KeyContext, 80) = .empty,

    pub fn init(allocator: Allocator) Cache {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Cache) void {
        var it = self.entries.valueIterator();
        while (it.next()) |resource| resource.*.destroy();
        self.entries.deinit(self.allocator);
    }

    pub fn getOrStart(self: *Cache, document: *runtime.Instance, input: RequestKey) !*Resource {
        var key = input;
        key.url = filePart(key.url);
        if (self.entries.get(key)) |resource| return resource;
        const resource = try self.allocator.create(Resource);
        errdefer self.allocator.destroy(resource);
        resource.* = .{
            .allocator = self.allocator,
            .key = try key.clone(self.allocator),
            .owner = document,
            .realm = document.ctx,
            .owner_generation = runtime.SlabAllocator.generationOf(document),
        };
        errdefer resource.key.deinit(self.allocator);
        try self.entries.putNoClobber(self.allocator, resource.key, resource);
        // A failure stays cached like any other completed invalid resource.
        resource.start() catch {};
        return resource;
    }

    pub fn markAbort(self: *Cache) bool {
        var marked = false;
        var it = self.entries.valueIterator();
        while (it.next()) |resource| {
            resource.*.abort_marked = resource.*.handle != null;
            marked = marked or resource.*.abort_marked;
        }
        return marked;
    }

    pub fn abortMarked(self: *Cache) void {
        var it = self.entries.valueIterator();
        while (it.next()) |resource| if (resource.*.abort_marked) resource.*.cancel();
    }
};

/// A use element observes a cache entry only while loading. The pending
/// native keep ends after its networking task or silent document abort.
/// Queued tasks own this small object, never a borrowed freed impl state.
pub const UseLoad = struct {
    allocator: Allocator,
    refs: usize = 1,
    element: *runtime.Instance,
    element_generation: u64,
    realm: runtime.Context,
    attached: bool = true,
    generation: u64 = 0,
    resource: ?*Resource = null,
    fragment: []u8 = &.{},
    document: ?*runtime.Instance = null,
    document_generation: u64 = 0,
    document_realm: ?runtime.Context = null,
    pending: bool = false,
    kept: bool = false,
    delaying_load: bool = false,
    abort_marked: ?u64 = null,

    pub fn create(element: *runtime.Instance) !*UseLoad {
        const self = try element.ctx.allocator.create(UseLoad);
        self.* = .{
            .allocator = element.ctx.allocator,
            .element = element,
            .element_generation = runtime.SlabAllocator.generationOf(element),
            .realm = element.ctx,
        };
        return self;
    }

    fn ownerLive(self: *const UseLoad) bool {
        return self.attached and self.realm.hasEngine() and runtime.SlabAllocator.generationOf(self.element) == self.element_generation;
    }

    fn documentLive(self: *const UseLoad) bool {
        const realm = self.document_realm orelse return false;
        if (!realm.hasEngine()) return false;
        const document = self.document orelse return false;
        return runtime.SlabAllocator.generationOf(document) == self.document_generation;
    }

    fn retain(self: *UseLoad) void {
        self.refs += 1;
    }
    fn release(self: *UseLoad) void {
        std.debug.assert(self.refs != 0);
        self.refs -= 1;
        if (self.refs != 0) return;
        std.debug.assert(!self.kept and self.resource == null);
        self.allocator.free(self.fragment);
        self.allocator.destroy(self);
    }

    pub fn destroy(self: *UseLoad) void {
        self.cancel();
        self.attached = false;
        self.release();
    }

    pub fn cancel(self: *UseLoad) void {
        self.generation +%= 1;
        self.abort_marked = null;
        if (self.resource) |resource| resource.removeClient(self);
        self.resource = null;
        self.finish();
    }

    fn finish(self: *UseLoad) void {
        self.pending = false;
        if (self.delaying_load) {
            self.delaying_load = false;
            if (self.documentLive()) lifecycle.undelayLoadEvent(self.document.?);
        }
        if (self.kept) {
            self.kept = false;
            if (self.ownerLive()) engine.releasePlatformObject(self.element);
        }
    }

    pub fn start(self: *UseLoad, input: []const u8) !void {
        self.cancel();
        if (!self.ownerLive() or input.len == 0) return;
        const node = @import("../instance_bridge.zig").getNodeBase(self.element) orelse return;
        if (!node.is_connected) return;
        const document = (try interfaces.Node.get_ownerDocument(self.element)) orelse return;
        if ((try interfaces.Document.get_defaultView(document)) == null) return;
        self.document = document;
        self.document_generation = runtime.SlabAllocator.generationOf(document);
        self.document_realm = document.ctx;
        const url = (try @import("../encoding_parse.zig").encodingParseAndSerialize(self.element, input)) orelse {
            self.beginPending();
            self.deliver(false);
            return;
        };
        defer self.allocator.free(url);
        const fragment = try self.allocator.dupe(u8, fragmentPart(url));
        self.allocator.free(self.fragment);
        self.fragment = fragment;
        // SVG 2 §16.1.7.1: same-document references never fetch. Their
        // mutation reflection belongs to the use shadow-tree prerequisite.
        const base = try interfaces.Node.get_baseURI(document);
        defer self.allocator.free(base);
        if (sameDocument(url, base)) return;
        self.beginPending();
        // SVG 2 §5.5 prohibits data URLs, even though Fetch can load them.
        if (std.ascii.startsWithIgnoreCase(url, "data:")) return self.deliver(false);
        const style_engine = hooks.engineOf(document) orelse return self.deliver(false);
        const state = style_engine.ensureResourceState(document) catch return self.deliver(false);
        const resource = state.svg.getOrStart(document, .{
            .url = url,
            .mode = .same_origin,
            .credentials = .include,
        }) catch return self.deliver(false);
        if (resource.status != .pending) return self.deliver(resource.lookup(self.fragment, .use) != null);
        resource.clients.append(self.allocator, self) catch return self.deliver(false);
        self.resource = resource;
    }

    fn beginPending(self: *UseLoad) void {
        self.pending = true;
        self.kept = true;
        engine.keepPlatformObjectAlive(self.element);
        self.delaying_load = true;
        lifecycle.delayLoadEvent(self.document.?);
    }

    pub fn markAbort(self: *UseLoad, document: *runtime.Instance) bool {
        if (!self.pending or self.document != document or !self.documentLive()) return false;
        self.abort_marked = self.generation;
        return true;
    }

    pub fn abortMarked(self: *UseLoad, document: *runtime.Instance) void {
        const mark = self.abort_marked orelse return;
        if (mark == self.generation and self.document == document) self.cancel();
    }

    fn deliver(self: *UseLoad, valid: bool) void {
        const loop = self.realm.getOptionalEventLoop() orelse return self.finish();
        const delivery = self.allocator.create(Delivery) catch return self.finish();
        self.retain();
        delivery.* = .{ .load = self, .generation = self.generation, .valid = valid };
        // SVG resource completion: networking task source. The Browser's
        // current task queue is one FIFO (liaison Q15); source separation
        // belongs to the event-loop owner, html/event_loop/task.zig.
        loop.queueTask(.{
            .callback = Delivery.run,
            .context = delivery,
            .drop = Delivery.drop,
            .document = self.document,
            .document_generation = self.document_generation,
        });
    }

    const Delivery = struct {
        load: *UseLoad,
        generation: u64,
        valid: bool,
        fn current(self: *const Delivery) bool {
            return self.load.ownerLive() and self.load.generation == self.generation;
        }
        fn deinit(self: *Delivery) void {
            const load = self.load;
            load.allocator.destroy(self);
            load.release();
        }
        fn drop(context: ?*anyopaque) void {
            const self: *Delivery = @ptrCast(@alignCast(context.?));
            defer self.deinit();
            if (self.current()) self.load.finish();
        }
        fn run(context: ?*anyopaque) void {
            const self: *Delivery = @ptrCast(@alignCast(context.?));
            defer self.deinit();
            if (!self.current()) return;
            defer if (self.current()) self.load.finish();
            engine.runTaskInRealm(self.load.realm, steps, self) catch {};
        }
        fn steps(context: ?*anyopaque) void {
            const self: *Delivery = @ptrCast(@alignCast(context.?));
            if (!self.current()) return;
            const element = self.load.element;
            const event = interfaces.Event.call_constructor(element.ctx, runtime.DOMString.initInterned(if (self.valid) "load" else "error"), webidl.Opt(@import("dictionaries").EventInit).notPassed()) catch return;
            const generation = runtime.SlabAllocator.generationOf(event);
            defer event.releaseIfUnwrapped(generation);
            _ = @import("../fire_event.zig").dispatchTrusted(element, event) catch {};
        }
    };
};
