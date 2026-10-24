//! CSS Fonts 4 §4 descriptors and CSS Font Loading 3's shared font state.
//! Descriptor parsing is independent of a FontFace wrapper or stylesheet;
//! both owners call this helper through their generated interfaces/hooks.

const std = @import("std");
const css = @import("css");
const Allocator = std.mem.Allocator;
const Stream = css.properties.Stream;
const values = css.style_values;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const fetch = @import("fetch");
const hooks = @import("hooks.zig");
const document_activity = @import("../document_activity.zig");
const Rule = @import("rules.zig").Rule;

/// Q7's approved interim: resolving state is owned only while pending.
/// Once settled, the owner keeps the promise through a collector-traced
/// edge. Pending reactions that reach the owner can retain it until its
/// realm ends; a traced-capability engine operation is a recorded follow-up.
pub const OwnerPromise = struct {
    capability: ?engine.PromiseCapability = null,
    initialized: bool = false,
    fulfilled: bool = false,
    slot: engine.TracedSlot,

    pub fn ensure(self: *OwnerPromise, owner: *runtime.Instance) !void {
        if (self.initialized) return;
        self.capability = try engine.createPromise(owner.ctx);
        self.initialized = true;
    }

    pub fn get(self: *OwnerPromise, owner: *runtime.Instance) !engine.Owned {
        try self.ensure(owner);
        if (self.capability) |capability| return engine.retainValue(owner.ctx, capability.promise);
        return engine.tracedValue(owner, self.slot) orelse error.InvalidStateError;
    }

    pub fn settle(self: *OwnerPromise, owner: *runtime.Instance, value: runtime.JSValue, rejected: bool) !void {
        try self.ensure(owner);
        const capability = if (self.capability) |*pending| pending else return;
        if (rejected) try engine.rejectPromise(capability, value) else try engine.resolvePromise(capability, value);
        self.fulfilled = !rejected;
        self.abandon(owner);
    }

    /// Realm/document destruction discards resolving state without changing
    /// the promise's identity or running an author reaction.
    pub fn abandon(self: *OwnerPromise, owner: *runtime.Instance) void {
        if (self.capability) |*capability| {
            engine.traceValue(owner, capability.promise, self.slot);
            engine.releasePromiseCapability(capability);
            self.capability = null;
        }
    }

    pub fn deinit(self: *OwnerPromise, owner: *runtime.Instance, owner_live: bool) void {
        if (self.capability) |*capability| engine.releasePromiseCapability(capability);
        if (self.initialized and owner_live) engine.forgetTracedChild(owner, self.slot);
        self.capability = null;
        self.initialized = false;
    }
};

/// Shared state reached only through the FontFace owner's hook. Its owner
/// pointer is a back link; loading owns an explicit pending-activity hold.
pub const Face = struct {
    owner: *runtime.Instance,
    generation: u64,
    realm: runtime.Context,
    allocator: Allocator,
    descriptors: FontRule,
    /// The connection owns a native rule reference. The rule's reverse
    /// notification is weak; descriptors are also kept as an independent
    /// snapshot so disconnecting needs no allocation (Font Loading §2.3).
    css_rule: ?*Rule = null,
    status: enum { unloaded, loading, loaded, failure } = .unloaded,
    failure: ?Failure = null,
    loaded: OwnerPromise = .{ .slot = .{ .name = "FontFace:loaded" } },
    load: ?*FaceLoad = null,
    binary: bool = false,
    retired: bool = false,
    memberships: std.ArrayList(InstanceLink) = .empty,

    pub const Failure = enum { syntax, network };

    pub fn init(owner: *runtime.Instance) Face {
        return .{ .owner = owner, .generation = runtime.SlabAllocator.generationOf(owner), .realm = owner.ctx, .allocator = owner.ctx.allocator, .descriptors = .{ .block = Block.init(owner.ctx.allocator) } };
    }

    pub fn ownerLive(self: *const Face) bool {
        return self.realm.hasEngine() and runtime.SlabAllocator.generationOf(self.owner) == self.generation;
    }

    pub fn deinit(self: *Face) void {
        self.releaseConnection();
        if (self.load) |load| {
            self.load = null;
            load.destroy();
        }
        self.loaded.deinit(self.owner, self.ownerLive());
        self.memberships.deinit(self.allocator);
        self.descriptors.deinit();
    }

    pub fn discard(self: *Face) void {
        const hold = engine.holdTeardowns(self.realm);
        defer hold.release();
        self.retired = true;
        if (self.load) |load| load.cancel();
        if (self.ownerLive()) self.loaded.abandon(self.owner);
    }

    /// Realm destruction ends the shared transport before any client's
    /// pending keep. Ordinary discard still cancels only this face.
    pub fn discardForRealm(self: *Face) void {
        const hold = engine.holdTeardowns(self.realm);
        defer hold.release();
        if (self.load) |load| if (load.resource) |resource| resource.cancel();
        self.discard();
    }

    pub fn markAbort(self: *Face, document: *runtime.Instance) bool {
        const load = self.load orelse return false;
        if (!load.kept or load.document != document or runtime.SlabAllocator.generationOf(document) != load.document_generation) return false;
        load.abort_marked = true;
        return true;
    }

    pub fn abortMarked(self: *Face, document: *runtime.Instance) void {
        const load = self.load orelse return;
        if (!load.abort_marked or load.document != document) return;
        const hold = engine.holdTeardowns(self.realm);
        defer hold.release();
        if (load.resource) |resource| resource.cancel();
        load.cancel();
        if (self.ownerLive()) self.loaded.abandon(self.owner);
    }

    pub fn emptyDescriptor(self: *Face, comptime name: []const u8) !void {
        _ = try setCanonicalDescriptor(&self.descriptors.block, name, try self.allocator.dupe(u8, ""));
    }

    pub fn getDescriptor(self: *const Face, comptime name: []const u8) []const u8 {
        if (descriptorIndex(&self.descriptors.block, name) != null) return descriptorValue(&self.descriptors.block, name);
        return descriptorDefault(name);
    }

    pub fn setDescriptorValue(self: *Face, comptime kind: Descriptor, comptime name: []const u8, text: []const u8) !void {
        // Font Loading 3 §2: a rejected setter leaves its old value intact.
        const parsed = if (kind == .family) try apiFamily(self.allocator, text) else (try parseDescriptor(self.allocator, kind, text)) orelse return error.SyntaxError;
        if (self.css_rule) |rule| {
            defer self.allocator.free(parsed);
            if (try rule.data.font_face.setProperty(.{ .allocator = rule.allocator }, name, parsed, "")) {
                if (rule.sheet()) |sheet| sheet.changed();
            }
        } else if (try setCanonicalDescriptor(&self.descriptors.block, name, parsed)) self.descriptorsChanged();
    }

    /// Font Loading 3 §2.3: an active rule creates one corresponding face
    /// per document font source. Complete every allocation before linking.
    pub fn connect(self: *Face, rule: *Rule) Allocator.Error!void {
        std.debug.assert(self.css_rule == null and rule.data == .font_face);
        var snapshot = try rule.data.font_face.clone(self.allocator);
        errdefer snapshot.deinit();
        try rule.data.font_face.connections.ensureUnusedCapacity(rule.allocator, 1);
        self.descriptors.deinit();
        self.descriptors = snapshot;
        rule.ref();
        self.css_rule = rule;
        rule.data.font_face.disconnect_face = Face.disconnect;
        rule.data.font_face.connections.appendAssumeCapacity(InstanceLink.to(self.owner));
    }

    fn releaseConnection(self: *Face) void {
        const rule = self.css_rule orelse return;
        self.css_rule = null;
        for (rule.data.font_face.connections.items, 0..) |link, index| {
            if (link.instance == self.owner and link.generation == self.generation) {
                _ = rule.data.font_face.connections.swapRemove(index);
                break;
            }
        }
        rule.unref();
    }

    /// Removal/src replacement permanently severs CSS ownership; a retained
    /// face keeps its descriptors, status promise and any in-flight source.
    fn disconnect(self: *Face) void {
        const hold = engine.holdTeardowns(self.realm);
        defer hold.release();
        self.releaseConnection();
        var index: usize = 0;
        while (index < self.memberships.items.len) {
            const link = self.memberships.items[index];
            if (link.isLive()) if (hooks.fontSetOf(link.instance)) |set| {
                if (set.removeCss(self.owner)) continue;
            };
            index += 1;
        }
    }

    fn descriptorsChanged(self: *Face) void {
        for (self.memberships.items) |link| if (link.isLive()) {
            if (hooks.fontSetOf(link.instance)) |set| set.environmentChanged();
        };
    }

    /// CSS-connected faces retain native status until script asks for the
    /// promise (WebKit FontFace::loadedForBindings/loadForBindings). Creating
    /// an unseen rejected JS promise during font selection would report an
    /// unhandled rejection. The explicit constructor still ensures eagerly.
    pub fn loadedPromise(self: *Face) !engine.Owned {
        try self.loaded.ensure(self.owner);
        try self.settleLoaded();
        return self.loaded.get(self.owner);
    }

    fn settleLoaded(self: *Face) !void {
        if (!self.loaded.initialized or self.loaded.capability == null) return;
        switch (self.status) {
            .unloaded, .loading => {},
            .loaded => try self.loaded.settle(self.owner, .{ .instance = self.owner }, false),
            .failure => {
                const name = switch (self.failure.?) {
                    .syntax => "SyntaxError",
                    .network => "NetworkError",
                };
                const exception = try engine.createDOMException(self.owner.ctx, name, "The font could not be loaded.");
                defer exception.release();
                try self.loaded.settle(self.owner, exception.borrow(), true);
            },
        }
    }

    pub fn reject(self: *Face, failure: Failure) !void {
        self.status = .failure;
        self.failure = failure;
        defer self.notifySets();
        try self.settleLoaded();
    }

    fn succeed(self: *Face) !void {
        self.status = .loaded;
        defer self.notifySets();
        try self.settleLoaded();
    }

    pub fn setSource(self: *Face, text: []const u8) !bool {
        const document = documentOfRealm(self.owner.ctx) orelse return false;
        var context = try @import("resource_loading.zig").inlineParseContext(document, self.allocator, false, text);
        defer context.deinit();
        return self.descriptors.setProperty(context.options(), "src", text, "");
    }

    pub fn start(self: *Face) !void {
        // Font Loading 3 §2.2 steps 2–4: a buffer or settled face keeps
        // the same status promise; an unloaded URL face starts once.
        if (self.retired or self.binary or self.status != .unloaded) return;
        const load = try FaceLoad.create(self, null);
        self.load = load;
        self.status = .loading;
        self.notifySets();
        load.queue(.next_source);
    }

    pub fn startBuffer(self: *Face, bytes: []const u8) !void {
        self.binary = true;
        const copy = try self.allocator.dupe(u8, bytes);
        errdefer self.allocator.free(copy);
        const load = try FaceLoad.create(self, copy);
        self.load = load;
        // §2.1 step 3: buffer parsing starts in a task, followed by a
        // separate task for its outcome, just like an asynchronous fetch.
        load.queue(.start_buffer);
    }

    fn notifySets(self: *Face) void {
        for (self.memberships.items) |link| if (link.isLive()) {
            if (hooks.fontSetOf(link.instance)) |set| set.faceStatusChanged(self);
        };
    }
};

fn descriptorDefault(comptime name: []const u8) []const u8 {
    return if (std.mem.eql(u8, name, "font-family")) "" else if (std.mem.eql(u8, name, "unicode-range")) "U+0-10FFFF" else if (std.mem.eql(u8, name, "font-display")) "auto" else "normal";
}

fn documentOfRealm(realm: runtime.Context) ?*runtime.Instance {
    if (!realm.isWindow()) return null;
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    return interfaces.Window.get_document(global) catch null;
}

/// One temporary validation boundary (Q2): the approved platform capability
/// will replace this answer. A successful HTTP response alone is NOT a font.
pub const FontValidation = enum { valid, invalid, cannot_validate };
pub fn validateFontData(_: []const u8) FontValidation {
    return .cannot_validate;
}

const resource_loading = @import("resource_loading.zig");

/// One document-owned transport, shared by equivalent font sources. Design:
/// WebKit CachedFont::beginLoadIfNeeded/didAddClient and CSSFontFaceSource's
/// FontLoadRequest clients. Each client owns its own face's pending activity;
/// this entry owns no platform root and never initiates an unused face.
pub const ResourceEntry = struct {
    allocator: Allocator,
    key: resource_loading.RequestKey,
    status: enum { pending, complete, failed } = .pending,
    validation: ?FontValidation = null,
    document: ?*runtime.Instance = null,
    document_generation: u64 = 0,
    handle: ?*fetch.algorithms.AsyncFetch = null,
    started: bool = false,
    clients: std.ArrayList(*FaceLoad) = .empty,
    abort_marked: bool = false,

    fn attach(self: *ResourceEntry, client: *FaceLoad) Allocator.Error!void {
        std.debug.assert(client.resource == null);
        if (self.status != .pending) {
            client.queue(if (self.validation == .valid) .success else .next_source);
            return;
        }
        // Finish the only client-list allocation before taking its ref.
        try self.clients.append(self.allocator, client);
        client.retain();
        client.resource = self;
        if (!self.started) self.start(client.document orelse unreachable) catch self.complete(.invalid);
    }

    fn start(self: *ResourceEntry, document: *runtime.Instance) !void {
        self.started = true;
        self.document = document;
        self.document_generation = runtime.SlabAllocator.generationOf(document);
        const global = try interfaces.Document.get_defaultView(document) orelse return error.InvalidStateError;
        const request = try fetch.internal.InternalRequest.init(self.allocator, self.key.url);
        var request_owned = true;
        defer if (request_owned) request.deinit();
        // CSS Fonts 4 §4.8.2: font requests are CORS, same-origin credentials.
        // The key also preserves the declaration's referrer and policy.
        request.destination = self.key.destination;
        request.mode = self.key.mode;
        request.credentials_mode = self.key.credentials;
        // CSS Values 4 §4.5.4 step 3: use URL credentials for style resources.
        request.use_url_credentials = true;
        request.referrer_policy = self.key.referrer_policy;
        request.initiator_type = if (self.key.origin_clean) .css else null;
        var client = try @import("../global_settings.zig").requestClient(global);
        defer client.deinit();
        try fetch.internal.populateRequestFromClient(request, client.request);
        if (self.key.referrer) |referrer| try request.setReferrerUrl(referrer);
        request_owned = false;
        self.handle = try fetch.algorithms.AsyncFetch.start(self.allocator, request, .{}, @import("../agent_fetches.zig").of(document.ctx), .{
            .context = self,
            .done = done,
            .alive = alive,
            .gone = gone,
            .finished = finished,
        });
    }

    fn alive(context: *anyopaque) bool {
        const self: *ResourceEntry = @ptrCast(@alignCast(context));
        const document = self.document orelse return false;
        return document_activity.activity(document, self.document_generation) != .gone;
    }
    fn gone(context: *anyopaque) void {
        const self: *ResourceEntry = @ptrCast(@alignCast(context));
        // AsyncFetch already terminated; it promises no later callback.
        self.handle = null;
        self.cancel();
    }
    fn finished(context: *anyopaque) void {
        const self: *ResourceEntry = @ptrCast(@alignCast(context));
        self.handle = null;
    }
    fn done(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        const self: *ResourceEntry = @ptrCast(@alignCast(context));
        var result = outcome catch return self.complete(.invalid);
        defer result.deinit();
        const response = result.response;
        if (response.response_type == .@"error" or !fetch.internal.isOkStatus(response.status)) return self.complete(.invalid);
        const body = response.body orelse return self.complete(.invalid);
        self.complete(validateFontData(body.getBytes()));
    }

    fn complete(self: *ResourceEntry, validation: FontValidation) void {
        const hold = engine.holdTeardowns(self.liveRealm());
        defer hold.release();
        self.validation = validation;
        self.status = if (validation == .valid) .complete else .failed;
        while (self.clients.pop()) |client| {
            client.resource = null;
            // Font Loading 3 §2.2: each face gets its own normal outcome
            // task, including a cache hit; no inline promise settlement.
            client.queue(if (validation == .valid) .success else .next_source);
            client.release();
        }
    }

    fn removeClient(self: *ResourceEntry, client: *FaceLoad) void {
        for (self.clients.items, 0..) |item, index| if (item == client) {
            _ = self.clients.swapRemove(index);
            client.resource = null;
            client.release();
            return;
        };
        unreachable;
    }

    pub fn cancel(self: *ResourceEntry) void {
        const hold = engine.holdTeardowns(self.liveRealm());
        defer hold.release();
        self.abort_marked = false;
        // Terminate first: releasing a client's last pending keep can run
        // native teardown. No callback may retain a freed cache entry.
        if (self.handle) |handle| {
            self.handle = null;
            handle.terminate();
        }
        if (self.status == .pending) {
            self.status = .failed;
            self.validation = .invalid;
        }
        while (self.clients.pop()) |client| {
            client.resource = null;
            // Abandon each resolving capability while its own pending keep
            // still protects the face. Another client's abort may have
            // cleared this client's abort marker before its owner is visited.
            if (client.ownerLive()) if (hooks.fontFaceOf(client.owner)) |face| face.loaded.abandon(client.owner);
            client.cancel();
            client.release();
        }
    }

    fn liveRealm(self: *const ResourceEntry) ?runtime.Context {
        const document = self.document orelse return null;
        if (runtime.SlabAllocator.generationOf(document) != self.document_generation) return null;
        return document.ctx;
    }

    fn destroy(self: *ResourceEntry) void {
        self.cancel();
        self.clients.deinit(self.allocator);
        self.key.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

/// Lazy, separate from image completion state. Cache keys own immutable
/// provenance; entries stay address-stable until their document destroys it.
pub const ResourceCache = struct {
    allocator: Allocator,
    entries: std.HashMapUnmanaged(resource_loading.RequestKey, *ResourceEntry, resource_loading.KeyContext, 80) = .empty,

    pub fn init(allocator: Allocator) ResourceCache {
        return .{ .allocator = allocator };
    }
    pub fn deinit(self: *ResourceCache) void {
        var entries = self.entries.valueIterator();
        while (entries.next()) |entry| entry.*.destroy();
        self.entries.deinit(self.allocator);
    }
    pub fn count(self: *const ResourceCache) usize {
        return self.entries.count();
    }
    pub fn getOrPut(self: *ResourceCache, key: resource_loading.RequestKey) Allocator.Error!struct { entry: *ResourceEntry, found_existing: bool } {
        if (self.entries.get(key)) |entry| return .{ .entry = entry, .found_existing = true };
        const entry = try self.allocator.create(ResourceEntry);
        errdefer self.allocator.destroy(entry);
        entry.* = .{ .allocator = self.allocator, .key = try key.clone(self.allocator) };
        errdefer entry.key.deinit(self.allocator);
        try self.entries.putNoClobber(self.allocator, entry.key, entry);
        return .{ .entry = entry, .found_existing = false };
    }
    pub fn markAbort(self: *ResourceCache) bool {
        var marked = false;
        var entries = self.entries.valueIterator();
        while (entries.next()) |entry| {
            entry.*.abort_marked = entry.*.handle != null;
            marked = entry.*.abort_marked or marked;
        }
        return marked;
    }
    pub fn abortMarked(self: *ResourceCache) void {
        var entries = self.entries.valueIterator();
        while (entries.next()) |entry| if (entry.*.abort_marked) entry.*.cancel();
    }
};

/// A shared resource and each queued task own this context independently of the face's
/// registry block. WebKit FontFace::fontStateChanged chooses SyntaxError
/// for buffer data and NetworkError for exhausted URL sources; its pending
/// activity keeps an observable loading face through that final outcome.
const FaceLoad = struct {
    allocator: Allocator,
    refs: usize = 1,
    owner: *runtime.Instance,
    owner_generation: u64,
    realm: runtime.Context,
    document: ?*runtime.Instance,
    document_generation: u64,
    sources: ?Sources,
    next_source: usize = 0,
    bytes: ?[]u8,
    resource: ?*ResourceEntry = null,
    attached: bool = true,
    canceled: bool = false,
    kept: bool = false,
    queued: bool = false,
    action: Action = .next_source,
    abort_marked: bool = false,

    const Action = enum { start_buffer, next_source, success, failure };

    fn create(face: *Face, bytes: ?[]u8) !*FaceLoad {
        const allocator = face.allocator;
        const self = try allocator.create(FaceLoad);
        errdefer allocator.destroy(self);
        const document = documentOfRealm(face.owner.ctx);
        self.* = .{
            .allocator = allocator,
            .owner = face.owner,
            .owner_generation = face.generation,
            .realm = face.owner.ctx,
            .document = document,
            .document_generation = if (document) |doc| runtime.SlabAllocator.generationOf(doc) else 0,
            .sources = if (face.descriptors.sources) |*sources| try cloneSources(allocator, sources) else null,
            .bytes = bytes,
        };
        engine.keepPlatformObjectAlive(self.owner);
        self.kept = true;
        return self;
    }

    fn retain(self: *FaceLoad) void {
        self.refs += 1;
    }
    fn release(self: *FaceLoad) void {
        self.refs -= 1;
        if (self.refs != 0) return;
        std.debug.assert(self.resource == null and !self.kept);
        if (self.sources) |*sources| sources.deinit();
        if (self.bytes) |bytes| self.allocator.free(bytes);
        self.allocator.destroy(self);
    }
    fn ownerLive(self: *const FaceLoad) bool {
        return self.attached and self.realm.hasEngine() and runtime.SlabAllocator.generationOf(self.owner) == self.owner_generation;
    }
    fn current(self: *const FaceLoad) bool {
        return !self.canceled and self.ownerLive();
    }
    fn finishPending(self: *FaceLoad) void {
        if (self.kept) {
            self.kept = false;
            if (self.ownerLive()) engine.releasePlatformObject(self.owner);
        }
    }
    fn cancel(self: *FaceLoad) void {
        self.canceled = true;
        self.abort_marked = false;
        if (self.resource) |resource| resource.removeClient(self);
        self.finishPending();
    }
    fn destroy(self: *FaceLoad) void {
        self.cancel();
        self.attached = false;
        self.release();
    }
    fn queue(self: *FaceLoad, action: Action) void {
        if (!self.current()) return;
        const loop = self.realm.getOptionalEventLoop() orelse {
            self.cancel();
            return;
        };
        std.debug.assert(!self.queued);
        self.action = action;
        self.queued = true;
        self.retain();
        // Font Loading's font-loading task source uses the live FIFO queue
        // until the separately recorded source-aware scheduler lands (Q15).
        loop.queueTask(.{ .callback = run, .drop = drop, .context = self, .document = self.document, .document_generation = self.document_generation });
    }
    fn run(context: ?*anyopaque) void {
        const self: *FaceLoad = @ptrCast(@alignCast(context orelse return));
        defer self.release();
        self.queued = false;
        if (!self.current()) return;
        engine.runTaskInRealm(self.realm, steps, self) catch {};
    }
    fn drop(context: ?*anyopaque) void {
        const self: *FaceLoad = @ptrCast(@alignCast(context orelse return));
        self.queued = false;
        self.cancel();
        self.release();
    }
    fn steps(context: ?*anyopaque) void {
        const self: *FaceLoad = @ptrCast(@alignCast(context orelse return));
        if (!self.current()) return;
        const face = hooks.fontFaceOf(self.owner) orelse return;
        switch (self.action) {
            .start_buffer => {
                face.status = .loading;
                face.notifySets();
                self.queue(if (validateFontData(self.bytes orelse &.{}) == .valid) .success else .failure);
            },
            .next_source => self.tryNext(),
            .success, .failure => {
                defer self.finishPending();
                if (self.action == .failure) face.reject(if (face.binary) .syntax else .network) catch {} else face.succeed() catch {};
            },
        }
    }
    fn tryNext(self: *FaceLoad) void {
        const sources = self.sources orelse {
            self.queue(.failure);
            return;
        };
        while (self.next_source < sources.items.len) {
            const source = sources.items[self.next_source];
            self.next_source += 1;
            // Local lookup is part of the pending platform capability; never
            // claim a local face exists based only on its family spelling.
            if (source.kind == .local) continue;
            const resource = source.resource orelse continue;
            if (!resource.valid) continue;
            self.startFetch(resource) catch continue;
            return;
        }
        self.queue(.failure);
    }
    fn startFetch(self: *FaceLoad, resource: values.ResourceUrl) !void {
        const document = self.document orelse return error.InvalidStateError;
        if (document_activity.activity(document, self.document_generation) == .gone) return error.InvalidStateError;
        const style = hooks.engineOf(document) orelse return error.InvalidStateError;
        const state = try style.ensureResourceState(document);
        const cache = try state.ensureFontCache();
        var key: resource_loading.RequestKey = .{ .url = resource.url, .destination = .font, .mode = .cors, .credentials = .same_origin };
        if (resource.source) |source| {
            key.referrer = source.referrer;
            key.referrer_policy = fetch.internal.policy_container.parseReferrerPolicyHeader(source.referrer_policy);
            key.origin_clean = source.origin_clean;
        }
        const result = try cache.getOrPut(key);
        try result.entry.attach(self);
    }
};

fn cloneSources(allocator: Allocator, original: *const Sources) Allocator.Error!Sources {
    var sources = (try parseSources(allocator, original.serialized)) orelse unreachable;
    errdefer sources.deinit();
    std.debug.assert(sources.items.len == original.items.len);
    for (sources.items, original.items) |*copy, source| {
        if (source.resource) |resource| copy.resource = try resource.clone(allocator, 0);
    }
    return sources;
}

pub const Descriptor = enum {
    family,
    style,
    weight,
    stretch,
    unicode_range,
    feature_settings,
    variation_settings,
    display,
    ascent_override,
    descent_override,
    line_gap_override,
    size,
    size_adjust,
    named_instance,
    language_override,
    superscript_position_override,
    subscript_position_override,
    superscript_size_override,
    subscript_size_override,
};

pub const UnicodeRange = struct {
    first: u21,
    last: u21,

    pub fn contains(self: UnicodeRange, codepoint: u21) bool {
        return codepoint >= self.first and codepoint <= self.last;
    }
};

/// CSS Fonts 4 §4.2: one <font-family-name>, unlike the font-family
/// property's list. Reuse that property's parser and CSS string serializer;
/// validate the descriptor's narrower grammar before calling it.
fn familyDescriptor(allocator: Allocator, text: []const u8) Allocator.Error!?[]u8 {
    var check = Stream.init(text);
    const first = check.next();
    if (first.token_type == .string) {
        if (!check.atEnd()) return null;
    } else if (first.token_type == .ident) {
        var words: usize = 1;
        while (!check.atEnd()) : (words += 1) {
            if (check.next().token_type != .ident) return null;
        }
        if (words == 1) {
            const name = try css.tokenizer.decode(allocator, first.value);
            defer allocator.free(name);
            if (css.properties.isGenericFamily(name) or values.CssWide.parse(name) != null or
                std.ascii.eqlIgnoreCase(name, "default")) return null;
        }
    } else return null;
    var stream = Stream.init(text);
    const value = (try css.properties.parseLonghand(.{ .allocator = allocator }, .font_family, &stream)) orelse return null;
    defer value.release();
    return try allocator.dupe(u8, value.sharedText().?.bytes);
}

/// CSSWG #6236 (2026-03-11): the FontFace API accepts a family name as
/// text, including names that CSS requires quoting. Chrome/Safari preserve
/// whitespace too (fontface-invalid-family.tentative.html). A stylesheet
/// descriptor still uses familyDescriptor's CSS grammar.
pub fn apiFamily(allocator: Allocator, name: []const u8) Allocator.Error![]u8 {
    if (try familyDescriptor(allocator, name)) |parsed| {
        if (std.mem.eql(u8, parsed, name) and (name.len == 0 or (name[0] != '"' and name[0] != '\''))) return parsed;
        allocator.free(parsed);
    }
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try values.appendString(name, &out, allocator);
    return try out.toOwnedSlice(allocator);
}

fn ident(token: css.Token, name: []const u8) bool {
    return token.token_type == .ident and css.tokenizer.nameEql(token.value, name);
}

fn oneKeyword(allocator: Allocator, stream: *Stream, allowed: []const []const u8) Allocator.Error!?[]u8 {
    const token = stream.next();
    if (!stream.atEnd()) return null;
    for (allowed) |name| if (ident(token, name)) return try allocator.dupe(u8, name);
    return null;
}

const Numeric = struct {
    value: f64,
    keyword: ?[]const u8 = null,
    suffix: []const u8 = "",

    fn append(self: Numeric, allocator: Allocator, out: *std.ArrayList(u8)) Allocator.Error!void {
        if (self.keyword) |name| {
            try out.appendSlice(allocator, name);
        } else {
            try values.appendNumber(self.value, out, allocator);
            try out.appendSlice(allocator, self.suffix);
        }
    }
};

fn numeric(token: css.Token, kind: Descriptor) ?Numeric {
    const n = token.numeric_value;
    switch (kind) {
        .weight => {
            if (ident(token, "normal")) return .{ .value = 400, .keyword = "normal" };
            if (ident(token, "bold")) return .{ .value = 700, .keyword = "bold" };
            if (token.token_type != .number or n == null or n.? < 1 or n.? > 1000) return null;
        },
        .stretch => {
            const widths = .{
                .{ "ultra-condensed", 50.0 }, .{ "extra-condensed", 62.5 },
                .{ "condensed", 75.0 },       .{ "semi-condensed", 87.5 },
                .{ "normal", 100.0 },         .{ "semi-expanded", 112.5 },
                .{ "expanded", 125.0 },       .{ "extra-expanded", 150.0 },
                .{ "ultra-expanded", 200.0 },
            };
            inline for (widths) |width| if (ident(token, width[0])) return .{ .value = width[1], .keyword = width[0] };
            if (token.token_type != .percentage or n == null or !std.math.isFinite(n.?) or n.? < 0) return null;
            return .{ .value = n.?, .suffix = "%" };
        },
        .style => {
            if (token.token_type != .dimension or n == null) return null;
            const unit = token.unit orelse return null;
            const degrees = if (css.tokenizer.nameEql(unit, "deg")) n.? else if (css.tokenizer.nameEql(unit, "grad")) n.? * 0.9 else if (css.tokenizer.nameEql(unit, "turn")) n.? * 360 else if (css.tokenizer.nameEql(unit, "rad")) n.? * 180 / std.math.pi else return null;
            if (!std.math.isFinite(degrees) or degrees < -90 or degrees > 90) return null;
            return .{ .value = degrees, .suffix = "deg" };
        },
        .ascent_override, .descent_override, .line_gap_override => {
            if (token.token_type != .percentage or n == null or !std.math.isFinite(n.?) or n.? < 0) return null;
            return .{ .value = n.?, .suffix = "%" };
        },
        else => unreachable,
    }
    if (!std.math.isFinite(n.?)) return null;
    return .{ .value = n.? };
}

/// CSS Fonts 4 §4.4 and §13.2: specified endpoints keep their order;
/// matching sorts them. A zero-width range serializes as one value.
fn numericDescriptor(allocator: Allocator, kind: Descriptor, stream: *Stream) Allocator.Error!?[]u8 {
    const token = stream.peek();
    // All three browsers reject left/right (integrator fontstyle probe,
    // 2026-10-22). CSSWG #9392 remains an explicit follow-up.
    if (kind == .style and !ident(token, "oblique")) return oneKeyword(allocator, stream, &.{ "auto", "normal", "italic" });
    if ((kind == .weight or kind == .stretch) and ident(token, "auto")) return oneKeyword(allocator, stream, &.{"auto"});
    const metric = kind == .ascent_override or kind == .descent_override or kind == .line_gap_override;
    if (metric and ident(token, "normal")) return oneKeyword(allocator, stream, &.{"normal"});
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    if (kind == .style) {
        _ = stream.next();
        try out.appendSlice(allocator, "oblique");
        if (stream.atEnd()) return try out.toOwnedSlice(allocator);
        try out.append(allocator, ' ');
    }
    const first = numeric(stream.next(), kind) orelse return null;
    try first.append(allocator, &out);
    if (!stream.atEnd()) {
        if (metric) return null;
        const second = numeric(stream.next(), kind) orelse return null;
        if (!stream.atEnd()) return null;
        if (second.value != first.value) {
            try out.append(allocator, ' ');
            try second.append(allocator, &out);
        }
    }
    return try out.toOwnedSlice(allocator);
}

/// CSS Fonts 4 §4.6 / §6.13 / §8.2: four printable ASCII tag bytes,
/// followed by a non-negative integer feature index or a variation number.
fn tagDescriptor(allocator: Allocator, kind: Descriptor, stream: *Stream) Allocator.Error!?[]u8 {
    if (ident(stream.peek(), "normal")) return oneKeyword(allocator, stream, &.{"normal"});
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    while (true) {
        const tag_token = stream.next();
        if (tag_token.token_type != .string) return null;
        const tag = try css.tokenizer.decode(allocator, tag_token.stringContents());
        defer allocator.free(tag);
        if (tag.len != 4) return null;
        for (tag) |byte| if (byte < 0x20 or byte > 0x7e) return null;
        try values.appendString(tag, &out, allocator);
        const token = stream.peek();
        var value: f64 = 1;
        if (kind == .variation_settings) {
            if (token.token_type != .number or token.numeric_value == null) return null;
            value = token.numeric_value.?;
            _ = stream.next();
        } else if (token.token_type == .number) {
            if (!token.is_integer or token.numeric_value == null or token.numeric_value.? < 0) return null;
            value = token.numeric_value.?;
            _ = stream.next();
        } else if (ident(token, "on") or ident(token, "off")) {
            value = if (ident(token, "on")) 1 else 0;
            _ = stream.next();
        }
        if (!std.math.isFinite(value)) return null;
        if (kind == .variation_settings or value != 1) {
            try out.append(allocator, ' ');
            try values.appendNumber(value, &out, allocator);
        }
        if (stream.atEnd()) break;
        if (stream.next().token_type != .comma) return null;
        try out.appendSlice(allocator, ", ");
    }
    return try out.toOwnedSlice(allocator);
}

pub fn parseDescriptor(allocator: Allocator, kind: Descriptor, text: []const u8) Allocator.Error!?[]u8 {
    if (@intFromEnum(kind) >= @intFromEnum(Descriptor.ascent_override)) return extendedDescriptor(allocator, kind, text);
    if (kind == .family) return familyDescriptor(allocator, text);
    if (kind == .unicode_range) {
        const ranges = (try parseUnicodeRanges(allocator, text)) orelse return null;
        defer allocator.free(ranges);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        for (ranges, 0..) |range, index| {
            if (index != 0) try out.appendSlice(allocator, ", ");
            var buffer: [32]u8 = undefined;
            const serialized = if (range.first == range.last)
                std.fmt.bufPrint(&buffer, "U+{X}", .{range.first}) catch unreachable
            else
                std.fmt.bufPrint(&buffer, "U+{X}-{X}", .{ range.first, range.last }) catch unreachable;
            try out.appendSlice(allocator, serialized);
        }
        return try out.toOwnedSlice(allocator);
    }
    var stream = Stream.init(text);
    return switch (kind) {
        .style, .weight, .stretch, .ascent_override, .descent_override, .line_gap_override => numericDescriptor(allocator, kind, &stream),
        .display => oneKeyword(allocator, &stream, &.{ "auto", "block", "swap", "fallback", "optional" }),
        .feature_settings, .variation_settings => tagDescriptor(allocator, kind, &stream),
        else => unreachable,
    };
}

fn nextNonWhitespace(tokenizer: *css.Tokenizer) css.Token {
    while (true) {
        const token = tokenizer.next();
        if (token.token_type != .whitespace) return token;
    }
}

/// CSS Syntax 3 §4.3.14 is a descriptor-only tokenization mode. The
/// common tokenizer handles comments/whitespace; only its U+ range token
/// (not produced in normal CSS tokenization) is consumed here. CSS Fonts 4
/// §4.5 then rejects reversed/out-of-Unicode ranges, including six '?'.
pub fn parseUnicodeRanges(allocator: Allocator, text: []const u8) Allocator.Error!?[]UnicodeRange {
    var ranges: std.ArrayList(UnicodeRange) = .empty;
    defer ranges.deinit(allocator);
    var tokenizer = css.Tokenizer.init(text);
    while (true) {
        const token = nextNonWhitespace(&tokenizer);
        if (token.token_type != .ident or token.value.len != 1 or std.ascii.toLower(token.value[0]) != 'u') return null;
        var position = tokenizer.pos;
        if (position >= text.len or text[position] != '+') return null;
        position += 1;
        var first: u32 = 0;
        var digits: usize = 0;
        while (position < text.len and digits < 6 and std.ascii.isHex(text[position])) : (digits += 1) {
            first = first * 16 + (std.fmt.charToDigit(text[position], 16) catch unreachable);
            position += 1;
        }
        var questions: usize = 0;
        while (position < text.len and digits + questions < 6 and text[position] == '?') : (questions += 1) position += 1;
        if (digits + questions == 0) return null;
        var last = first;
        if (questions != 0) {
            for (0..questions) |_| {
                first *= 16;
                last = last * 16 + 15;
            }
        } else if (position + 1 < text.len and text[position] == '-' and std.ascii.isHex(text[position + 1])) {
            position += 1;
            digits = 0;
            last = 0;
            while (position < text.len and digits < 6 and std.ascii.isHex(text[position])) : (digits += 1) {
                last = last * 16 + (std.fmt.charToDigit(text[position], 16) catch unreachable);
                position += 1;
            }
        }
        if (last > 0x10ffff or first > last) return null;
        try ranges.append(allocator, .{ .first = @intCast(first), .last = @intCast(last) });
        tokenizer.pos = position;
        const after = nextNonWhitespace(&tokenizer);
        if (after.token_type == .eof) break;
        if (after.token_type != .comma) return null;
    }
    return try ranges.toOwnedSlice(allocator);
}

/// CSS Fonts 4 §4.5: do not download a face for text outside its range.
pub fn textIntersects(ranges: []const UnicodeRange, text: []const u8) bool {
    // FontFaceSet's sample text is CSSOMString (DOMString), represented
    // by WTF-8. An unpaired surrogate must not discard adjacent characters.
    const view = std.unicode.Wtf8View.init(text) catch return false;
    var iterator = view.iterator();
    while (iterator.nextCodepoint()) |codepoint| {
        for (ranges) |range| if (range.contains(codepoint)) return true;
    }
    return false;
}

pub const Source = struct {
    pub const Kind = enum { local, url };
    kind: Kind,
    /// Decoded family name or URL, before resolution against its source.
    value: []u8,
    serialized: []u8,
    /// End of the URL component, before format()/tech() hints.
    url_end: usize,
    /// Captured only when this source is installed in an owning rule/face.
    resource: ?values.ResourceUrl = null,

    fn deinit(self: Source, allocator: Allocator) void {
        if (self.resource) |resource| resource.deinit(allocator);
        allocator.free(self.value);
        allocator.free(self.serialized);
    }
};

pub const Sources = struct {
    allocator: Allocator,
    items: []Source,
    serialized: []u8,

    pub fn deinit(self: *Sources) void {
        for (self.items) |source| source.deinit(self.allocator);
        self.allocator.free(self.items);
        self.allocator.free(self.serialized);
    }
};

/// Provisional platform support, separate from syntax and font-data
/// validation (liaison Q8). color-svg follows Firefox 158/Safari 27 over
/// Chrome 151 (2026-10-22 integrator cv-{chrome,firefox,safari}.json probes).
/// collection remains valid src syntax even though supports() is false.
/// Reconcile with the platform font capability;
/// recognizing a hint NEVER makes downloaded bytes a valid font.
pub fn provisionallySupportsFontHint(kind: enum { format, tech }, name: []const u8) bool {
    const supported: []const []const u8 = switch (kind) {
        .format => &.{ "collection", "opentype", "truetype", "woff", "woff2", "opentype-variations", "truetype-variations", "woff-variations", "woff2-variations" },
        .tech => &.{ "features-opentype", "features-aat", "color-colrv0", "color-colrv1", "color-sbix", "color-cbdt", "color-svg", "variations", "palettes" },
    };
    for (supported) |entry| if (std.ascii.eqlIgnoreCase(entry, name)) return true;
    return false;
}

fn function(token: css.Token, name: []const u8) bool {
    return token.token_type == .function and css.tokenizer.nameEql(token.value, name);
}

/// CSS Fonts 4 §4.3.1: parse each top-level comma component independently.
/// The common tokenizer protects strings, escaped commas and bad URLs;
/// balanced functions protect the commas inside tech().
pub fn parseSources(allocator: Allocator, text: []const u8) Allocator.Error!?Sources {
    var entries: std.ArrayList(Source) = .empty;
    defer entries.deinit(allocator);
    errdefer for (entries.items) |source| source.deinit(allocator);
    var serialized: std.ArrayList(u8) = .empty;
    defer serialized.deinit(allocator);
    var tokenizer = css.Tokenizer.init(text);
    var depth: usize = 0;
    var begin: usize = 0;
    while (true) {
        const token = tokenizer.next();
        switch (token.token_type) {
            .left_paren, .left_bracket, .left_brace => depth += 1,
            .right_paren, .right_bracket, .right_brace => depth -|= 1,
            else => {},
        }
        if (token.token_type == .eof or (token.token_type == .comma and depth == 0)) {
            const end = if (token.token_type == .eof) text.len else @intFromPtr(token.value.ptr) - @intFromPtr(text.ptr);
            if (try parseSource(allocator, text[begin..end])) |source| {
                var owned = source;
                errdefer owned.deinit(allocator);
                if (entries.items.len != 0) try serialized.appendSlice(allocator, ", ");
                try serialized.appendSlice(allocator, source.serialized);
                try entries.append(allocator, source);
            }
            begin = tokenizer.pos;
            if (token.token_type == .eof) break;
        }
    }
    if (entries.items.len == 0) return null;
    const output = try serialized.toOwnedSlice(allocator);
    errdefer allocator.free(output);
    return .{ .allocator = allocator, .items = try entries.toOwnedSlice(allocator), .serialized = output };
}

fn parseSource(allocator: Allocator, text: []const u8) Allocator.Error!?Source {
    var stream = Stream.init(text);
    const first = stream.next();
    var kind: Source.Kind = .url;
    var value: []u8 = undefined;
    if (function(first, "local")) {
        kind = .local;
        if (stream.next().token_type != .left_paren) return null;
        const begin = stream.tok.pos;
        var end = begin;
        while (true) {
            const token = stream.next();
            if (token.token_type == .eof) return null;
            if (token.token_type == .right_paren) {
                end = @intFromPtr(token.value.ptr) - @intFromPtr(text.ptr);
                break;
            }
            if (token.token_type != .ident and token.token_type != .string) return null;
        }
        if (!stream.atEnd()) return null;
        const canonical = (try familyDescriptor(allocator, text[begin..end])) orelse return null;
        defer allocator.free(canonical);
        var family = Stream.init(canonical);
        const token = family.next();
        value = if (token.token_type == .string)
            try css.tokenizer.decode(allocator, token.stringContents())
        else
            try allocator.dupe(u8, canonical);
    } else if (first.token_type == .url) {
        value = try css.tokenizer.decode(allocator, first.value);
    } else if (function(first, "url") or function(first, "src")) {
        if (stream.next().token_type != .left_paren) return null;
        const token = stream.next();
        if (token.token_type != .string or stream.next().token_type != .right_paren) return null;
        value = try css.tokenizer.decode(allocator, token.stringContents());
    } else return null;
    var keep_value = false;
    defer if (!keep_value) allocator.free(value);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.appendSlice(allocator, if (kind == .local) "local(" else "url(");
    try values.appendString(value, &out, allocator);
    try out.append(allocator, ')');
    const url_end = out.items.len;
    if (kind == .url and function(stream.peek(), "format")) {
        _ = stream.next();
        if (stream.next().token_type != .left_paren) return null;
        const token = stream.next();
        if ((token.token_type != .string and token.token_type != .ident) or stream.next().token_type != .right_paren) return null;
        const decoded = try css.tokenizer.decode(allocator, if (token.token_type == .string) token.stringContents() else token.value);
        defer allocator.free(decoded);
        _ = std.ascii.lowerString(decoded, decoded);
        // Legacy -variations names are strings only, not format keywords.
        if (token.token_type == .ident and std.mem.endsWith(u8, decoded, "-variations")) return null;
        if (!provisionallySupportsFontHint(.format, decoded)) return null;
        try out.appendSlice(allocator, " format(");
        if (token.token_type == .string) try values.appendString(decoded, &out, allocator) else try out.appendSlice(allocator, decoded);
        try out.append(allocator, ')');
    }
    if (kind == .url and function(stream.peek(), "tech")) {
        _ = stream.next();
        if (stream.next().token_type != .left_paren) return null;
        try out.appendSlice(allocator, " tech(");
        while (true) {
            const token = stream.next();
            if (token.token_type != .ident) return null;
            const decoded = try css.tokenizer.decode(allocator, token.value);
            defer allocator.free(decoded);
            _ = std.ascii.lowerString(decoded, decoded);
            if (!provisionallySupportsFontHint(.tech, decoded)) return null;
            try out.appendSlice(allocator, decoded);
            const separator = stream.next();
            if (separator.token_type == .right_paren) break;
            if (separator.token_type != .comma) return null;
            try out.appendSlice(allocator, ", ");
        }
        try out.append(allocator, ')');
    }
    if (!stream.atEnd()) return null;
    const serialized = try out.toOwnedSlice(allocator);
    keep_value = true;
    return .{ .kind = kind, .value = value, .serialized = serialized, .url_end = url_end };
}

/// CSS Fonts 4 §§4.7/4.10 and Fonts 5 §§4.3–4.6. Two-axis metric
/// values differ from a variable-font range: omitted line metrics default
/// to normal, whereas omitted superscript/subscript metrics repeat x.
fn extendedDescriptor(allocator: Allocator, kind: Descriptor, text: []const u8) Allocator.Error!?[]u8 {
    var stream = Stream.init(text);
    if (kind == .named_instance or kind == .language_override) {
        const keyword = if (kind == .named_instance) "auto" else "normal";
        if (ident(stream.peek(), keyword)) return oneKeyword(allocator, &stream, &.{keyword});
        const token = stream.next();
        if (token.token_type != .string or !stream.atEnd()) return null;
        const decoded = try css.tokenizer.decode(allocator, token.stringContents());
        defer allocator.free(decoded);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try values.appendString(decoded, &out, allocator);
        return try out.toOwnedSlice(allocator);
    }
    if (kind == .size and ident(stream.peek(), "auto")) return oneKeyword(allocator, &stream, &.{"auto"});
    const line_metric = kind == .ascent_override or kind == .descent_override or kind == .line_gap_override;
    const signed = kind == .superscript_position_override or kind == .subscript_position_override or kind == .size;
    const keyword_allowed = kind != .size and kind != .size_adjust;
    var items: [2]Numeric = undefined;
    var count: usize = 0;
    while (!stream.atEnd()) {
        if (count == 2 or (count == 1 and kind == .size_adjust)) return null;
        const token = stream.next();
        const item: Numeric = if (keyword_allowed and ident(token, "normal"))
            .{ .value = 0, .keyword = "normal" }
        else if (keyword_allowed and !line_metric and ident(token, "from-font"))
            .{ .value = 0, .keyword = "from-font" }
        else blk: {
            if (token.token_type != (if (kind == .size) css.TokenType.number else .percentage)) return null;
            const n = token.numeric_value orelse return null;
            if (!std.math.isFinite(n) or (!signed and n < 0)) return null;
            break :blk .{ .value = n, .suffix = if (kind == .size) "" else "%" };
        };
        items[count] = item;
        count += 1;
    }
    if (count == 0) return null;
    if (count == 2) {
        if (line_metric) {
            if (items[1].keyword) |name| if (std.mem.eql(u8, name, "normal")) {
                count = 1;
            };
        } else if (items[0].value == items[1].value and optionalKeywordEqual(items[0].keyword, items[1].keyword)) count = 1;
    }
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    for (items[0..count], 0..) |item, i| {
        if (i != 0) try out.append(allocator, ' ');
        try item.append(allocator, &out);
    }
    return try out.toOwnedSlice(allocator);
}

fn optionalKeywordEqual(a: ?[]const u8, b: ?[]const u8) bool {
    return if (a) |left| if (b) |right| std.mem.eql(u8, left, right) else false else b == null;
}

const descriptor_names = std.StaticStringMap(Descriptor).initComptime(.{
    .{ "font-family", .family },                                  .{ "font-style", .style },                                            .{ "font-weight", .weight },
    .{ "font-stretch", .stretch },                                .{ "font-width", .stretch },                                          .{ "unicode-range", .unicode_range },
    .{ "font-feature-settings", .feature_settings },              .{ "font-variation-settings", .variation_settings },                  .{ "font-display", .display },
    .{ "ascent-override", .ascent_override },                     .{ "descent-override", .descent_override },                           .{ "line-gap-override", .line_gap_override },
    .{ "font-size", .size },                                      .{ "size-adjust", .size_adjust },                                     .{ "font-named-instance", .named_instance },
    .{ "font-language-override", .language_override },            .{ "superscript-position-override", .superscript_position_override }, .{ "subscript-position-override", .subscript_position_override },
    .{ "superscript-size-override", .superscript_size_override }, .{ "subscript-size-override", .subscript_size_override },
});

const Block = css.declarations.DeclarationBlock;

fn canonicalName(name: []const u8, buffer: *[64]u8) ?[]const u8 {
    if (name.len > buffer.len) return null;
    const lowered = std.ascii.lowerString(buffer[0..name.len], name);
    // The legacy alias is one descriptor, not two cascade candidates.
    return if (std.mem.eql(u8, lowered, "font-width")) "font-stretch" else lowered;
}

fn descriptorIndex(block: *const Block, name: []const u8) ?usize {
    var buffer: [64]u8 = undefined;
    const canonical = canonicalName(name, &buffer) orelse return null;
    for (block.entries.items, 0..) |entry, i| {
        if (std.mem.eql(u8, entry.name(), canonical)) return i;
    }
    return null;
}

pub fn descriptorValue(block: *const Block, name: []const u8) []const u8 {
    const index = descriptorIndex(block, name) orelse return "";
    return switch (block.entries.items[index]) {
        .unparsed => |entry| entry.value,
        .typed => "",
    };
}

/// CSSOM set/remove descriptor. Empty values remove before priority
/// validation, as setProperty step 3 specifies. @font-face has no important
/// descriptors (CSS Syntax's at-rule declaration context).
pub fn setDescriptor(block: *Block, name: []const u8, text: []const u8, priority: []const u8) Allocator.Error!bool {
    var buffer: [64]u8 = undefined;
    const canonical = canonicalName(name, &buffer) orelse return false;
    const is_source = std.mem.eql(u8, canonical, "src");
    const kind = descriptor_names.get(canonical);
    if (!is_source and kind == null) return false;
    if (text.len == 0) {
        const index = descriptorIndex(block, canonical) orelse return false;
        const entry = block.entries.orderedRemove(index).unparsed;
        block.allocator.free(entry.name);
        block.allocator.free(entry.value);
        return true;
    }
    if (priority.len != 0) return false;
    const value = if (is_source) blk: {
        var sources = (try parseSources(block.allocator, text)) orelse return false;
        defer sources.deinit();
        break :blk try block.allocator.dupe(u8, sources.serialized);
    } else (try parseDescriptor(block.allocator, kind.?, text)) orelse return false;
    return setCanonicalDescriptor(block, canonical, value);
}

/// Takes value even on failure. Existing entries change only after all
/// fallible work for that entry has succeeded.
fn setCanonicalDescriptor(block: *Block, canonical: []const u8, value: []u8) Allocator.Error!bool {
    var owned = true;
    defer if (owned) block.allocator.free(value);
    if (descriptorIndex(block, canonical)) |index| {
        const entry = &block.entries.items[index].unparsed;
        if (std.mem.eql(u8, entry.value, value)) return false;
        block.allocator.free(entry.value);
        entry.value = value;
        owned = false;
        return true;
    }
    const owned_name = try block.allocator.dupe(u8, canonical);
    errdefer block.allocator.free(owned_name);
    try block.entries.append(block.allocator, .{ .unparsed = .{ .name = owned_name, .value = value, .important = false } });
    owned = false;
    return true;
}

pub fn descriptorsFromDeclarations(allocator: Allocator, declarations: []const css.rules.Declaration) Allocator.Error!Block {
    var block = Block.init(allocator);
    errdefer block.deinit();
    for (declarations) |declaration| {
        if (declaration.important) continue;
        _ = try setDescriptor(&block, declaration.name, declaration.value, "");
    }
    return block;
}

pub fn descriptorBlock(allocator: Allocator, text: []const u8) Allocator.Error!Block {
    const declarations = try css.rules.parseDeclarationList(allocator, text);
    defer css.rules.freeDeclarationList(allocator, declarations);
    return descriptorsFromDeclarations(allocator, declarations);
}

pub fn setDescriptorText(block: *Block, text: []const u8) Allocator.Error!void {
    const replacement = try descriptorBlock(block.allocator, text);
    block.deinit();
    block.* = replacement;
}

/// CSS Fonts 4 §4.3 and CSS Values 4 §4.5.4: a rule owns the ordered
/// sources and their immutable declaring context, independently of its
/// mutable parent-sheet back link. No parsing operation starts a fetch.
pub const FontRule = struct {
    block: Block,
    sources: ?Sources = null,
    connections: std.ArrayList(InstanceLink) = .empty,
    // A parsed rule has no runtime connection. Install this only when a
    // Face connects, keeping native-only stylesheet destruction independent
    // of the engine (Q52); the callback still uses the engine protocol.
    disconnect_face: ?*const fn (*Face) void = null,

    /// A face retains an independent snapshot even after its stylesheet or
    /// source connection ends (Font Loading 3 §2.3). Preserve the already
    /// resolved source provenance; never resolve URLs while cloning.
    pub fn clone(self: *const FontRule, allocator: Allocator) Allocator.Error!FontRule {
        var copy: FontRule = .{ .block = Block.init(allocator) };
        errdefer copy.deinit();
        for (self.block.entries.items) |entry| switch (entry) {
            .unparsed => |descriptor| {
                _ = try setCanonicalDescriptor(&copy.block, descriptor.name, try allocator.dupe(u8, descriptor.value));
            },
            .typed => unreachable,
        };
        if (self.sources) |*sources| copy.sources = try cloneSources(allocator, sources);
        return copy;
    }

    pub fn deinit(self: *FontRule) void {
        // Every connected Face owns a Rule ref, so the rule cannot reach
        // its final unref while one of these weak links is still live.
        std.debug.assert(self.connections.items.len == 0);
        self.connections.deinit(self.block.allocator);
        if (self.sources) |*sources| sources.deinit();
        self.block.deinit();
    }

    pub fn fromDeclarations(options: css.properties.ParseOptions, declarations: []const css.rules.Declaration) Allocator.Error!FontRule {
        var result: FontRule = .{ .block = Block.init(options.allocator) };
        errdefer result.deinit();
        for (declarations) |declaration| {
            if (declaration.important) continue;
            _ = try result.setProperty(options, declaration.name, declaration.value, "");
        }
        return result;
    }

    pub fn fromText(options: css.properties.ParseOptions, text: []const u8) Allocator.Error!FontRule {
        const declarations = try css.rules.parseDeclarationList(options.allocator, text);
        defer css.rules.freeDeclarationList(options.allocator, declarations);
        return fromDeclarations(options, declarations);
    }

    pub fn setCssText(self: *FontRule, options: css.properties.ParseOptions, text: []const u8) Allocator.Error!void {
        var owned_options = options;
        owned_options.allocator = self.block.allocator;
        var replacement = try fromText(owned_options, text);
        errdefer replacement.deinit();
        try self.replaceWith(replacement);
    }

    pub fn setProperty(self: *FontRule, options: css.properties.ParseOptions, name: []const u8, text: []const u8, priority: []const u8) Allocator.Error!bool {
        if (self.connections.items.len == 0) return self.setPropertyRaw(options, name, text, priority);
        var replacement = try self.clone(self.block.allocator);
        var owned = true;
        defer if (owned) replacement.deinit();
        if (!try replacement.setPropertyRaw(options, name, text, priority)) return false;
        try self.replaceWith(replacement);
        owned = false;
        return true;
    }

    fn setPropertyRaw(self: *FontRule, options: css.properties.ParseOptions, name: []const u8, text: []const u8, priority: []const u8) Allocator.Error!bool {
        var buffer: [64]u8 = undefined;
        const canonical = canonicalName(name, &buffer) orelse return false;
        if (!std.mem.eql(u8, canonical, "src")) return setDescriptor(&self.block, canonical, text, priority);
        if (text.len == 0) {
            const changed = try setDescriptor(&self.block, canonical, text, priority);
            if (changed) {
                if (self.sources) |*sources| sources.deinit();
                self.sources = null;
            }
            return changed;
        }
        if (priority.len != 0) return false;
        const allocator = self.block.allocator;
        var replacement = (try parseSources(allocator, text)) orelse return false;
        var taken = false;
        defer if (!taken) replacement.deinit();
        for (replacement.items) |*source| {
            if (source.kind != .url) continue;
            // Resolve each accepted URL once. Empty and failed URLs stay
            // as invalid entries so fallback ordering is not rewritten.
            const resolved = if (source.value.len != 0) blk: {
                const resolver = options.url_resolver orelse break :blk null;
                break :blk resolver.resolve(resolver.context, allocator, source.value);
            } else null;
            defer if (resolved) |url| allocator.free(url);
            const resource = values.ResourceUrl.describe(source.value, resolved, options.url_resolver != null, options.resource_source, .{ .start = 0, .end = source.url_end });
            source.resource = try resource.clone(allocator, 0);
        }
        const metadata_changed = if (self.sources) |*old| !sourceListsEqual(old, &replacement) else true;
        const changed = try setCanonicalDescriptor(&self.block, "src", try allocator.dupe(u8, replacement.serialized));
        if (!changed and !metadata_changed) return false;
        if (self.sources) |*old| old.deinit();
        self.sources = replacement;
        taken = true;
        return true;
    }

    /// Takes replacement on success only. Stage all face snapshots before
    /// mutating any descriptor, so OOM cannot split two-way reflection.
    fn replaceWith(self: *FontRule, replacement: FontRule) Allocator.Error!void {
        const sources_changed = if (self.sources) |*old|
            if (replacement.sources) |*next| !sourceListsEqual(old, next) else true
        else
            replacement.sources != null;
        if (sources_changed) {
            self.disconnectAll();
            self.deinit();
            self.* = replacement;
            return;
        }
        const Pending = struct { face: InstanceLink, snapshot: FontRule };
        var pending: std.ArrayList(Pending) = .empty;
        defer {
            for (pending.items) |*item| item.snapshot.deinit();
            pending.deinit(self.block.allocator);
        }
        for (self.connections.items) |link| {
            if (!link.isLive()) continue;
            const face = hooks.fontFaceOf(link.instance) orelse continue;
            if (face.css_rule == null or &face.css_rule.?.data.font_face != self) continue;
            var snapshot = try replacement.clone(face.allocator);
            errdefer snapshot.deinit();
            try pending.append(self.block.allocator, .{ .face = link, .snapshot = snapshot });
        }
        const links = self.connections;
        const disconnect = self.disconnect_face;
        self.connections = .empty;
        self.deinit();
        self.* = replacement;
        self.connections = links;
        self.disconnect_face = disconnect;
        for (pending.items) |*item| {
            if (!item.face.isLive()) continue;
            const face = hooks.fontFaceOf(item.face.instance) orelse continue;
            face.descriptors.deinit();
            face.descriptors = item.snapshot;
            item.snapshot = .{ .block = Block.init(face.allocator) };
            face.descriptorsChanged();
        }
    }

    fn disconnectAll(self: *FontRule) void {
        const disconnect = self.disconnect_face orelse {
            std.debug.assert(self.connections.items.len == 0);
            return;
        };
        // Keep the containing Rule while dropping the Faces' references.
        var kept: ?*Rule = null;
        for (self.connections.items) |link| if (link.isLive()) {
            const face = hooks.fontFaceOf(link.instance) orelse continue;
            if (face.css_rule) |rule| {
                kept = rule;
                rule.ref();
                break;
            }
        };
        defer if (kept) |rule| rule.unref();
        while (self.connections.pop()) |link| {
            if (!link.isLive()) continue;
            const face = hooks.fontFaceOf(link.instance) orelse continue;
            if (face.css_rule) |rule| if (&rule.data.font_face == self) disconnect(face);
        }
    }
};

/// Font-only lifecycle walk. Existing CSSOM parent links keep their own
/// semantics; no rule is parsed or face created on removal/teardown.
pub fn disconnectRule(rule: *Rule) void {
    rule.ref();
    defer rule.unref();
    if (rule.data == .font_face) rule.data.font_face.disconnectAll();
    if (rule.children()) |children| for (children.items) |child| disconnectRule(child);
    if (rule.data == .import) if (rule.data.import.child) |sheet| {
        if (sheet.rules) |rules| for (rules.items) |child| disconnectRule(child);
    };
}

/// Font Loading 3 §2.3: removing a sheet from its document disconnects
/// its existing faces immediately, even if it is re-adopted in this task.
/// Shadow adoption is separate from the document font source (Q37).
pub fn adoptedSheetsChanged(owner: *runtime.Instance, previous: []const *@import("sheet.zig").SheetRecord, values_: []const *runtime.Instance) void {
    const node = @import("../instance_bridge.zig").getNodeBase(owner) orelse return;
    if (node.node_type != @import("../node_base.zig").NodeBase.DOCUMENT_NODE) return;
    const hold = engine.holdTeardowns(owner.ctx);
    defer hold.release();
    for (previous) |sheet| {
        const retained = for (values_) |value| {
            if (hooks.sheetRecordOf(value) == sheet) break true;
        } else false;
        if (retained) continue;
        // This path neither parses a lazy sheet nor creates a FontFace.
        if (sheet.rules) |rules| for (rules.items) |rule| disconnectRule(rule);
    }
}

fn sourceListsEqual(a: *const Sources, b: *const Sources) bool {
    if (a.items.len != b.items.len) return false;
    for (a.items, b.items) |left, right| {
        if (left.kind != right.kind or !std.mem.eql(u8, left.serialized, right.serialized)) return false;
        if (left.resource) |resource| {
            if (right.resource) |other| {
                if (!resource.eql(other)) return false;
            } else return false;
        } else if (right.resource != null) return false;
    }
    return true;
}

/// CSS Fonts 4 §5.2: a variable face represents every value in each range.
/// The caller assembles one family, then handles unicode-range/composite
/// ordering and font data coverage after these three axes are narrowed.
pub const MatchRange = struct {
    first: f64,
    last: f64,

    fn low(self: MatchRange) f64 {
        return @min(self.first, self.last);
    }
    fn high(self: MatchRange) f64 {
        return @max(self.first, self.last);
    }
    fn contains(self: MatchRange, value: f64) bool {
        return self.low() <= value and value <= self.high();
    }
};
pub const MatchStyle = struct {
    axis: enum { oblique, italic } = .oblique,
    range: MatchRange = .{ .first = 0, .last = 0 },
};
pub const MatchFace = struct {
    width: MatchRange = .{ .first = 100, .last = 100 },
    style: MatchStyle = .{},
    weight: MatchRange = .{ .first = 400, .last = 400 },
};
pub const MatchRequest = struct {
    width: f64 = 100,
    style: enum { normal, italic, oblique } = .normal,
    angle: f64 = 14,
    weight: f64 = 400,
};

const MatchRank = struct {
    stage: u8 = std.math.maxInt(u8),
    distance: f64 = 0,

    fn before(self: MatchRank, other: MatchRank) bool {
        return self.stage < other.stage or (self.stage == other.stage and self.distance < other.distance);
    }
    fn eql(self: MatchRank, other: MatchRank) bool {
        return self.stage == other.stage and self.distance == other.distance;
    }
};

fn widthRank(range: MatchRange, desired: f64) MatchRank {
    if (range.contains(desired)) return .{ .stage = 0 };
    const below = range.high() < desired;
    return .{
        .stage = if (below == (desired <= 100)) 1 else 2,
        .distance = if (below) desired - range.high() else range.low() - desired,
    };
}

fn weightRank(range: MatchRange, desired: f64) MatchRank {
    if (range.contains(desired)) return .{ .stage = 0 };
    const below = range.high() < desired;
    if (desired >= 400 and desired <= 500) {
        if (!below and range.low() <= 500) return .{ .stage = 1, .distance = range.low() - desired };
        return .{ .stage = if (below) 2 else 3, .distance = if (below) desired - range.high() else range.low() - 500 };
    }
    return .{
        .stage = if (below == (desired < 400)) 1 else 2,
        .distance = if (below) desired - range.high() else range.low() - desired,
    };
}

const StyleSegment = struct {
    axis: @FieldType(MatchStyle, "axis"),
    low: f64,
    high: f64,
    ascending: bool,
    low_open: bool = false,
    high_open: bool = false,

    fn distance(self: StyleSegment, style: MatchStyle) ?f64 {
        if (style.axis != self.axis) return null;
        const low = @max(style.range.low(), self.low);
        const high = @min(style.range.high(), self.high);
        if (low > high) return null;
        if ((self.low_open and high <= self.low) or (self.high_open and low >= self.high)) return null;
        return if (self.ascending) low - self.low else self.high - high;
    }
};

fn styleRank(face: MatchStyle, request: MatchRequest) MatchRank {
    // CSS Fonts 4 §5.2 step 4.2: negative oblique angles reflect both
    // axes and all search directions, rather than using absolute distance.
    const negative = request.style == .oblique and request.angle < 0;
    const style = if (negative) MatchStyle{
        .axis = face.axis,
        .range = .{ .first = -face.range.high(), .last = -face.range.low() },
    } else face;
    const angle = @abs(request.angle);
    const infinity = std.math.inf(f64);
    if (request.style == .normal) {
        const segments = [_]StyleSegment{
            .{ .axis = .oblique, .low = 0, .high = infinity, .ascending = true },
            .{ .axis = .italic, .low = 0, .high = infinity, .ascending = true },
            .{ .axis = .oblique, .low = -infinity, .high = 0, .high_open = true, .ascending = false },
            .{ .axis = .italic, .low = -infinity, .high = 0, .high_open = true, .ascending = false },
        };
        for (segments, 0..) |segment, i| {
            if (segment.distance(style)) |distance| return .{ .stage = @intCast(i), .distance = distance };
        }
        return .{};
    }
    const primary: @FieldType(MatchStyle, "axis") = if (request.style == .italic) .italic else .oblique;
    const secondary: @FieldType(MatchStyle, "axis") = if (primary == .italic) .oblique else .italic;
    const desired: f64 = if (request.style == .italic) 1 else angle;
    const fallback: f64 = if (request.style == .italic) 11 else 1;
    if (style.axis == primary and style.range.contains(desired)) return .{ .stage = 0 };
    const ascending_first = request.style == .italic or angle >= 11;
    const primary_up = StyleSegment{ .axis = primary, .low = desired, .high = infinity, .ascending = true, .low_open = desired == 0 };
    const primary_down = StyleSegment{ .axis = primary, .low = 0, .high = desired, .ascending = false, .low_open = true };
    // CSS Fonts 4 §5.2's small-oblique step 4 says <1 then >1, omitting
    // exactly italic=1. Include that boundary (liaison Q24): WebKit's
    // FontSelectionAlgorithm::styleDistance and Blink's StyleDistance
    // retain an italic-only family rather than eliminating its only face.
    // The negative-angle reflection above includes the mirrored boundary.
    const secondary_up = StyleSegment{ .axis = secondary, .low = fallback, .high = infinity, .ascending = true };
    const secondary_down = StyleSegment{ .axis = secondary, .low = 0, .high = fallback, .ascending = false, .low_open = true, .high_open = !ascending_first };
    const segments = [_]StyleSegment{
        if (ascending_first) primary_up else primary_down,
        if (ascending_first) primary_down else primary_up,
        if (ascending_first) secondary_up else secondary_down,
        if (ascending_first) secondary_down else secondary_up,
        .{ .axis = primary, .low = -infinity, .high = 0, .ascending = false },
        .{ .axis = secondary, .low = -infinity, .high = 0, .ascending = false },
    };
    for (segments, 1..) |segment, i| {
        if (segment.distance(style)) |distance| return .{ .stage = @intCast(i), .distance = distance };
    }
    return .{};
}

/// Returns owned indices in original order. Equal choices all survive so
/// composite faces can later intersect the text's Unicode ranges. Families
/// have already been matched with infra.unicode_case.eqlFold (§5.1).
pub fn matchFaces(allocator: Allocator, faces: []const MatchFace, request: MatchRequest) Allocator.Error![]usize {
    var selected: std.ArrayList(usize) = .empty;
    errdefer selected.deinit(allocator);
    try selected.ensureTotalCapacity(allocator, faces.len);
    for (faces, 0..) |_, index| selected.appendAssumeCapacity(index);
    // CSS Fonts 4 §5.2 step 4: width, style and weight, in that order.
    inline for (.{ "width", "style", "weight" }) |axis| {
        var best = MatchRank{};
        for (selected.items) |index| {
            const rank = if (comptime std.mem.eql(u8, axis, "width")) widthRank(faces[index].width, request.width) else if (comptime std.mem.eql(u8, axis, "style")) styleRank(faces[index].style, request) else weightRank(faces[index].weight, request.weight);
            if (rank.before(best)) best = rank;
        }
        var retained: usize = 0;
        for (selected.items) |index| {
            const rank = if (comptime std.mem.eql(u8, axis, "width")) widthRank(faces[index].width, request.width) else if (comptime std.mem.eql(u8, axis, "style")) styleRank(faces[index].style, request) else weightRank(faces[index].weight, request.weight);
            if (best.stage != std.math.maxInt(u8) and rank.eql(best)) {
                selected.items[retained] = index;
                retained += 1;
            }
        }
        selected.items.len = retained;
    }
    return selected.toOwnedSlice(allocator);
}

/// Decoded family names and descriptors, borrowed for a single selection.
/// The CSS font shorthand parser supplies one family at a time; this helper
/// neither reparses its grammar nor substitutes a system font for it.
pub const FamilyFace = struct {
    family: []const u8,
    matching: MatchFace = .{},
    ranges: []const UnicodeRange = &.{.{ .first = 0, .last = 0x10ffff }},
};

pub const FamilyMatch = struct {
    /// Owned indices into the caller's faces, in their original order.
    indices: []usize,
    /// Font Loading 3 §3.1 step 7, before text/range filtering.
    found_faces: bool,
};

/// Font Loading 3 §3.1 steps 6–9 for ONE already-decoded family. Narrow
/// the numeric axes before intersecting unicode-range: an uncovered text
/// must not select a different weight or style. Blink FontFaceSet::load
/// and Gecko FontFaceSetImpl::FindMatchingFontFaces follow this ordering.
pub fn matchFamilyForText(allocator: Allocator, faces: []const FamilyFace, family: []const u8, request: MatchRequest, text: []const u8) Allocator.Error!FamilyMatch {
    var matches: std.ArrayList(MatchFace) = .empty;
    defer matches.deinit(allocator);
    var original_indices: std.ArrayList(usize) = .empty;
    defer original_indices.deinit(allocator);
    for (faces, 0..) |face, index| {
        // CSS Fonts 4 §5.1: full default case folding, without Unicode
        // normalization or locale-specific tailorings.
        if (!@import("infra").unicode_case.eqlFold(face.family, family)) continue;
        try matches.append(allocator, face.matching);
        try original_indices.append(allocator, index);
    }
    const narrowed = try matchFaces(allocator, matches.items, request);
    defer allocator.free(narrowed);
    var selected: std.ArrayList(usize) = .empty;
    errdefer selected.deinit(allocator);
    for (narrowed) |index| {
        const original = original_indices.items[index];
        if (textIntersects(faces[original].ranges, text)) try selected.append(allocator, original);
    }
    return .{ .indices = try selected.toOwnedSlice(allocator), .found_faces = narrowed.len != 0 };
}

/// Decode a family from an already parsed CSS serialization. This is a
/// temporary adapter for current computed longhands (Q58), not a property
/// or shorthand parser. Row119's typed FontRequest replaces it.
fn readFamily(allocator: Allocator, stream: *Stream) Allocator.Error!?struct { name: []u8, generic: bool } {
    const first = stream.next();
    if (first.token_type == .string) {
        return .{ .name = try css.tokenizer.decode(allocator, first.stringContents()), .generic = false };
    }
    if (first.token_type != .ident) return null;
    var name: std.ArrayList(u8) = .empty;
    errdefer name.deinit(allocator);
    var token = first;
    var words: usize = 0;
    while (true) {
        const decoded = try css.tokenizer.decode(allocator, token.value);
        defer allocator.free(decoded);
        if (words != 0) try name.append(allocator, ' ');
        try name.appendSlice(allocator, decoded);
        words += 1;
        if (stream.peek().token_type != .ident) break;
        token = stream.next();
    }
    const generic = words == 1 and css.properties.isGenericFamily(name.items);
    return .{ .name = try name.toOwnedSlice(allocator), .generic = generic };
}

fn matchingRange(text: []const u8, kind: Descriptor, initial: f64) MatchRange {
    var stream = Stream.init(text);
    const first = numeric(stream.next(), kind) orelse return .{ .first = initial, .last = initial };
    const last = if (stream.atEnd()) first else numeric(stream.next(), kind) orelse first;
    return .{ .first = first.value, .last = last.value };
}

fn matchingDescriptors(face: *const Face) MatchFace {
    var result: MatchFace = .{
        .width = matchingRange(face.getDescriptor("font-stretch"), .stretch, 100),
        .weight = matchingRange(face.getDescriptor("font-weight"), .weight, 400),
    };
    var stream = Stream.init(face.getDescriptor("font-style"));
    const token = stream.next();
    if (ident(token, "italic")) {
        result.style = .{ .axis = .italic, .range = .{ .first = 1, .last = 1 } };
    } else if (ident(token, "oblique")) {
        const first = if (stream.atEnd()) Numeric{ .value = 14 } else numeric(stream.next(), .style) orelse Numeric{ .value = 14 };
        const last = if (stream.atEnd()) first else numeric(stream.next(), .style) orelse first;
        result.style.range = .{ .first = first.value, .last = last.value };
    }
    // Fonts 4 §4.4: auto selects as normal on all three axes.
    return result;
}

/// One rendering/ready-flush pass. The owning set traces its members;
/// these synchronous borrowed links never survive the caller's hold.
const UsedFonts = struct {
    allocator: Allocator,
    entries: std.ArrayList(Entry) = .empty,

    const Entry = struct {
        face: *Face,
        family: []u8,
        ranges: []UnicodeRange,
        matching: MatchFace,
    };

    fn init(set: *Set) Allocator.Error!UsedFonts {
        var self = UsedFonts{ .allocator = set.allocator };
        errdefer self.deinit();
        for (set.members.items) |member| {
            if (!member.face.isLive()) continue;
            const face = hooks.fontFaceOf(member.face.instance) orelse continue;
            // Fonts 4 §5.2 step 3: failed resources are not present in the
            // matching family. Pending ones still block older composites.
            if (face.retired or face.status == .failure) continue;
            var stream = Stream.init(face.getDescriptor("font-family"));
            const family = (try readFamily(self.allocator, &stream)) orelse continue;
            errdefer self.allocator.free(family.name);
            const ranges = (try parseUnicodeRanges(self.allocator, face.getDescriptor("unicode-range"))) orelse {
                self.allocator.free(family.name);
                continue;
            };
            errdefer self.allocator.free(ranges);
            try self.entries.append(self.allocator, .{ .face = face, .family = family.name, .ranges = ranges, .matching = matchingDescriptors(face) });
        }
        return self;
    }

    fn deinit(self: *UsedFonts) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry.family);
            self.allocator.free(entry.ranges);
        }
        self.entries.deinit(self.allocator);
    }

    fn selectText(self: *UsedFonts, style: *const css.computed_style.ComputedStyle, content: []const u8) !void {
        if (content.len == 0) return;
        const families = style.get(.font_family);
        // Generic families map to platform fonts, not identically named
        // @font-face declarations. Quoted generic names remain ordinary.
        if (families != .text) return;
        var request = MatchRequest{};
        const style_value = style.get(.font_style);
        if (style_value == .keyword) switch (style_value.keyword) {
            .italic => request.style = .italic,
            .oblique => request.style = .oblique,
            else => {},
        };
        const weight = style.get(.font_weight);
        if (weight == .number) request.weight = weight.number;
        // Q58: font-stretch is not yet supported; its computed initial
        // value is normal (100%). No private shorthand/property parser.
        var stream = Stream.init(families.text.bytes);
        while (!stream.atEnd()) {
            const family = (try readFamily(self.allocator, &stream)) orelse break;
            defer self.allocator.free(family.name);
            if (!family.generic) try self.selectFamily(family.name, request, content);
            if (stream.atEnd() or stream.next().token_type != .comma) break;
        }
    }

    fn selectControl(self: *UsedFonts, element: *runtime.Instance) !void {
        const input = element.stateAs(interfaces.HTMLInputElement.State) != null;
        const textarea = element.stateAs(interfaces.HTMLTextAreaElement.State) != null;
        const select = element.stateAs(interfaces.HTMLSelectElement.State) != null;
        if (!input and !textarea and !select) return;
        var kind = if (input) try interfaces.HTMLInputElement.get_type(element) else runtime.DOMString.initEmpty();
        defer kind.deinit(element.ctx.allocator);
        const text_entry = input and (std.mem.eql(u8, kind.asSlice(), "text") or
            std.mem.eql(u8, kind.asSlice(), "search") or std.mem.eql(u8, kind.asSlice(), "url") or
            std.mem.eql(u8, kind.asSlice(), "tel") or std.mem.eql(u8, kind.asSlice(), "email") or
            std.mem.eql(u8, kind.asSlice(), "password"));
        const button = input and (std.mem.eql(u8, kind.asSlice(), "button") or
            std.mem.eql(u8, kind.asSlice(), "submit") or std.mem.eql(u8, kind.asSlice(), "reset"));
        const file = input and std.mem.eql(u8, kind.asSlice(), "file");
        // Q66: numeric/date/range/color/checkable controls await evidence.
        if (input and !text_entry and !button and !file) return;
        const style = (try @import("engine.zig").fontStyleForControl(element)) orelse return;
        // Fonts 4 §5.2's first available font uses U+0020, even when no
        // character is displayed. Q62 confirms this for rendered controls.
        try self.selectText(style, " ");
        if (select) {
            // Q62: ALL option text contributes, including unselected options.
            // The ordinary DOM text walk already visits each option's text.
            return;
        }
        const labels = @import("../control_labels.zig");
        if (file) {
            try self.selectText(style, labels.choose_file);
            // Q66: selected filename display belongs to the picker follow-up.
            const files = try interfaces.HTMLInputElement.get_files(element);
            if (files == null or try interfaces.FileList.get_length(files.?) == 0)
                try self.selectText(style, labels.no_file);
            return;
        }
        var value = if (textarea) try interfaces.HTMLTextAreaElement.get_value(element) else try interfaces.HTMLInputElement.get_value(element);
        defer value.deinit(element.ctx.allocator);
        if (button) {
            if (try interfaces.Element.call_hasAttribute(element, .initInterned("value"))) {
                try self.selectText(style, value.asSlice());
            } else if (std.mem.eql(u8, kind.asSlice(), "submit")) {
                try self.selectText(style, labels.submit);
            } else if (std.mem.eql(u8, kind.asSlice(), "reset")) {
                try self.selectText(style, labels.reset);
            }
        } else if (!value.isEmpty()) {
            // HTML 15.5.6 obscures password data. Repeated mask characters
            // select the same face, so match the shared glyph once.
            try self.selectText(style, if (std.mem.eql(u8, kind.asSlice(), "password")) labels.password_mask else value.asSlice());
        } else {
            var placeholder = if (textarea) try interfaces.HTMLTextAreaElement.get_placeholder(element) else try interfaces.HTMLInputElement.get_placeholder(element);
            defer placeholder.deinit(element.ctx.allocator);
            if (!placeholder.isEmpty()) {
                const hint_style = (try @import("engine.zig").computedStyle(element, "placeholder")) orelse style;
                try self.selectText(hint_style, placeholder.asSlice());
            }
        }
    }

    fn selectFamily(self: *UsedFonts, name: []const u8, request: MatchRequest, text: []const u8) !void {
        var axes: std.ArrayList(MatchFace) = .empty;
        defer axes.deinit(self.allocator);
        var indices: std.ArrayList(usize) = .empty;
        defer indices.deinit(self.allocator);
        for (self.entries.items, 0..) |entry, index| {
            if (!@import("infra").unicode_case.eqlFold(entry.family, name)) continue;
            try axes.append(self.allocator, entry.matching);
            try indices.append(self.allocator, index);
        }
        if (indices.items.len == 0) return;
        const selected = try matchFaces(self.allocator, axes.items, request);
        defer self.allocator.free(selected);
        const needed = try self.allocator.alloc(bool, selected.len);
        defer self.allocator.free(needed);
        @memset(needed, false);
        const view = std.unicode.Wtf8View.init(text) catch return;
        var codepoints = view.iterator();
        while (codepoints.nextCodepoint()) |codepoint| {
            // Fonts 4 §5.2 step 5: later rules win overlapping composite
            // ranges. A failed selected face is reconsidered next turn.
            var i = selected.len;
            while (i > 0) {
                i -= 1;
                const entry = self.entries.items[indices.items[selected[i]]];
                const covers = for (entry.ranges) |range| {
                    if (range.contains(codepoint)) break true;
                } else false;
                if (!covers) continue;
                needed[i] = true;
                break;
            }
        }
        var i = selected.len;
        while (i > 0) {
            i -= 1;
            if (needed[i]) try self.entries.items[indices.items[selected[i]]].face.start();
        }
        // §4.8.1 permits requesting a computed fallback family even when
        // a preceding installed font might cover the run. Q2 supplies no
        // character map yet; do not invent glyph/cluster coverage here.
    }
};

/// CSS Fonts 4 §5.2: discover only fonts needed by rendered text. Read
/// borrowed text through the owning DOM hook, never another impl's state.
pub fn selectUsedFonts(set: *Set) !void {
    const document = set.liveDocument() orelse return;
    if (set.retired or set.members.items.len == 0) return;
    const hold = engine.holdTeardowns(set.realm);
    defer hold.release();
    var selector = try UsedFonts.init(set);
    defer selector.deinit();
    if (selector.entries.items.len == 0) return;
    const bridge = @import("../instance_bridge.zig");
    const NodeBase = @import("../node_base.zig").NodeBase;
    const root = bridge.getNodeBase(document) orelse return;
    var nodes = try @import("../tree_helpers.zig").getShadowIncludingInclusiveDescendants(set.allocator, root);
    defer nodes.deinit();
    for (nodes.items()) |node| {
        if (!node.is_connected) continue;
        const instance: *runtime.Instance = @ptrCast(@alignCast(bridge.getInstance(node) orelse continue));
        if (node.node_type == NodeBase.TEXT_NODE) {
            const text = @import("../character_data.zig").dataOf(instance) orelse continue;
            if (text.len == 0) continue;
            const style = (try @import("engine.zig").fontStyleForText(node)) orelse continue;
            try selector.selectText(style, text);
        } else if (node.node_type == NodeBase.ELEMENT_NODE) {
            try selector.selectControl(instance);
            for ([_][]const u8{ "before", "after" }) |pseudo| {
                const style = (try @import("engine.zig").computedStyle(instance, pseudo)) orelse continue;
                if (style.display().box == .none or style.display().box == .contents) continue;
                const content = style.get(.content);
                if (content != .content) continue;
                _ = (try @import("engine.zig").fontStyleForGeneratedText(instance, style)) orelse continue;
                const visual_end = content.content.alternate orelse content.content.items.len;
                for (content.content.items[0..visual_end]) |item| {
                    if (item.kind == .text) try selector.selectText(style, item.text);
                }
            }
        }
    }
}

/// Q63: value writes change rendered glyphs without a DOM mutation. The
/// common no-font-interest path is O(1), allocates nothing and never fetches.
pub fn controlValueChanged(element: *runtime.Instance, has_style_state: bool) void {
    // A control's first selection is already pending through insertion or
    // style changes. Its owner remembers the first ElementStyle creation;
    // that state survives cache drops. The false path needs no lookup.
    if (!has_style_state) return;
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    const style = hooks.engineOf(document) orelse return;
    const resources = style.resourceState() orelse return;
    if (!resources.font_interested) return;
    // The bridge lookup takes a mutex. An uninterested document needs no
    // connectedness query; keep that lookup on the active-font path only.
    const node = @import("../instance_bridge.zig").getNodeBase(element) orelse return;
    if (!node.is_connected) return;
    resources.invalidate();
}

/// Q48: Blink and Gecko update font selection when a previously settled
/// ready promise is read after invalidation. Never select images or settle
/// ready here; those actions belong to the rendering opportunity.
pub fn flushSettledReady(set: *Set) !void {
    if (!set.ready.fulfilled or set.retired) return;
    const document = set.liveDocument() orelse return;
    const style = hooks.engineOf(document) orelse return;
    const resources = style.resourceState() orelse return;
    if (!resources.pending or !document_activity.fullyActive(document, resources.document_generation)) return;
    try selectUsedFonts(set);
}

const InstanceLink = struct {
    instance: *runtime.Instance,
    generation: u64,
    realm: runtime.Context,

    fn to(instance: *runtime.Instance) InstanceLink {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance), .realm = instance.ctx };
    }
    fn isLive(self: InstanceLink) bool {
        return self.realm.hasEngine() and runtime.SlabAllocator.generationOf(self.instance) == self.generation;
    }
};

/// Font Loading 3 §3's ordered set and status lists. A member is traced from
/// this set; its reverse notification link is generation-checked and weak.
/// The generic WebIDL interface-valued setlike adapter is a separate owner.
pub const Set = struct {
    owner: *runtime.Instance,
    generation: u64,
    realm: runtime.Context,
    allocator: Allocator,
    /// Document owns this set. This is a non-owning back link (Q4).
    document: ?InstanceLink,
    ready: OwnerPromise = .{ .slot = .{ .name = "FontFaceSet:ready" } },
    members: std.ArrayList(Member) = .empty,
    status: enum { loading, loaded } = .loaded,
    next_id: u64 = 0,
    retired: bool = false,
    environment_pending: bool = true,

    pub const Member = struct {
        face: InstanceLink,
        id: u64,
        state: enum { idle, loading, loaded, failed } = .idle,
        css_connected: bool = false,
    };

    pub fn init(owner: *runtime.Instance, document: ?*runtime.Instance) Set {
        return .{ .owner = owner, .generation = runtime.SlabAllocator.generationOf(owner), .realm = owner.ctx, .allocator = owner.ctx.allocator, .document = if (document) |doc| InstanceLink.to(doc) else null };
    }
    pub fn ownerLive(self: *const Set) bool {
        return self.realm.hasEngine() and runtime.SlabAllocator.generationOf(self.owner) == self.generation;
    }
    pub fn liveDocument(self: *const Set) ?*runtime.Instance {
        const link = self.document orelse return null;
        return if (link.isLive()) link.instance else null;
    }
    pub fn deinit(self: *Set) void {
        for (self.members.items) |member| self.endMember(member);
        self.members.deinit(self.allocator);
        self.ready.deinit(self.owner, self.ownerLive());
    }
    pub fn discard(self: *Set) void {
        self.retired = true;
        if (self.ownerLive()) self.ready.abandon(self.owner);
    }
    fn indexOf(self: *const Set, face: *runtime.Instance) ?usize {
        for (self.members.items, 0..) |member, index| if (member.face.instance == face and member.face.isLive()) return index;
        return null;
    }
    fn memberSlot(id: u64, buffer: *[64]u8) engine.TracedSlot {
        return .{ .name = std.fmt.bufPrint(buffer, "FontFaceSet:member:{d}", .{id}) catch unreachable };
    }
    pub fn add(self: *Set, instance: *runtime.Instance) !void {
        if (self.indexOf(instance) != null) return;
        const face = hooks.fontFaceOf(instance) orelse return error.InvalidStateError;
        // Font Loading 3 §3 add steps 1–2: existing entries are a no-op;
        // a CSS-connected face cannot be added to a different font source.
        if (face.css_rule != null) return error.InvalidModificationError;
        try self.addMember(face, false);
    }
    fn addMember(self: *Set, face: *Face, css_connected: bool) !void {
        const instance = face.owner;
        try self.members.ensureUnusedCapacity(self.allocator, 1);
        try face.memberships.ensureUnusedCapacity(face.allocator, 1);
        const id = self.next_id;
        self.next_id += 1;
        self.members.appendAssumeCapacity(.{ .face = InstanceLink.to(instance), .id = id, .css_connected = css_connected });
        face.memberships.appendAssumeCapacity(InstanceLink.to(self.owner));
        var slot_buffer: [64]u8 = undefined;
        engine.traceChild(self.owner, instance, memberSlot(id, &slot_buffer));
        if (face.status == .loading) self.faceStatusChanged(face);
        self.environmentChanged();
    }
    fn endMember(self: *Set, member: Member) void {
        if (member.face.isLive()) if (hooks.fontFaceOf(member.face.instance)) |face| {
            for (face.memberships.items, 0..) |link, index| if (link.instance == self.owner and link.generation == self.generation) {
                _ = face.memberships.orderedRemove(index);
                break;
            };
        };
        if (self.ownerLive()) {
            var slot_buffer: [64]u8 = undefined;
            engine.forgetTracedChild(self.owner, memberSlot(member.id, &slot_buffer));
        }
    }
    pub fn remove(self: *Set, face: *runtime.Instance) bool {
        const index = self.indexOf(face) orelse return false;
        if (self.members.items[index].css_connected) return false;
        const member = self.members.orderedRemove(index);
        self.endMember(member);
        self.environmentChanged();
        return true;
    }
    fn removeCss(self: *Set, face: *runtime.Instance) bool {
        const index = self.indexOf(face) orelse return false;
        if (!self.members.items[index].css_connected) return false;
        const member = self.members.orderedRemove(index);
        self.endMember(member);
        self.environmentChanged();
        return true;
    }
    pub fn clear(self: *Set) void {
        var index: usize = self.members.items.len;
        while (index > 0) {
            index -= 1;
            if (self.members.items[index].css_connected) continue;
            self.endMember(self.members.orderedRemove(index));
        }
        self.environmentChanged();
    }

    /// Font Loading 3 §§2.3/4.2: reconcile native CSS entries without
    /// loading any font. Gecko's FontFaceSetDocumentImpl::UpdateRules
    /// retains surviving identities, orders CSS entries first, and removes
    /// duplicates before appending non-rule faces. Take that design only.
    pub fn reconcile(self: *Set) !void {
        if (self.retired) return;
        const document = self.liveDocument() orelse return;
        const Gather = struct {
            allocator: Allocator,
            document: *runtime.Instance,
            rules: std.ArrayList(*Rule) = .empty,

            pub fn visit(gather: *@This(), rule: *Rule, root: *runtime.Instance) !void {
                // Q37: document scope only until typed tree-scoped font
                // references arrive from row119. Never leak a shadow face.
                if (root != gather.document or rule.data != .font_face) return;
                const font = &rule.data.font_face;
                if (font.sources == null or descriptorValue(&font.block, "font-family").len == 0) return;
                for (gather.rules.items) |existing| if (existing == rule) return;
                try gather.rules.append(gather.allocator, rule);
                rule.ref();
            }
            fn deinit(gather: *@This()) void {
                for (gather.rules.items) |rule| rule.unref();
                gather.rules.deinit(gather.allocator);
            }
        };
        var gather: Gather = .{ .allocator = self.allocator, .document = document };
        defer gather.deinit();
        // The active-rule visitor lends its compiled pointers and forbids
        // mutation. Finish the whole borrowed walk before changing faces.
        try @import("engine.zig").visitFontRules(document, &gather);

        const hold = engine.holdTeardowns(self.realm);
        defer hold.release();
        var index: usize = 0;
        while (index < self.members.items.len) {
            const member = self.members.items[index];
            if (!member.css_connected) {
                index += 1;
                continue;
            }
            const face = if (member.face.isLive()) hooks.fontFaceOf(member.face.instance) else null;
            const present = if (face) |f| blk: {
                const rule = f.css_rule orelse break :blk false;
                for (gather.rules.items) |desired| if (desired == rule) break :blk true;
                break :blk false;
            } else false;
            if (present) {
                index += 1;
                continue;
            }
            if (face) |f| {
                f.disconnect();
            } else {
                self.endMember(self.members.orderedRemove(index));
            }
        }

        for (gather.rules.items, 0..) |rule, position| {
            const existing = for (self.members.items, 0..) |member, i| {
                if (!member.css_connected or !member.face.isLive()) continue;
                const face = hooks.fontFaceOf(member.face.instance) orelse continue;
                if (face.css_rule == rule) break i;
            } else null;
            const found = if (existing) |i| i else blk: {
                const instance = try interfaces.FontFace.init(self.allocator, self.realm);
                const generation = runtime.SlabAllocator.generationOf(instance);
                defer instance.releaseIfUnwrapped(generation);
                const face = hooks.fontFaceOf(instance) orelse return error.InvalidStateError;
                try face.connect(rule);
                try self.addMember(face, true);
                break :blk self.members.items.len - 1;
            };
            if (found != position) {
                const member = self.members.items[found];
                std.mem.copyBackwards(Member, self.members.items[position + 1 .. found + 1], self.members.items[position..found]);
                self.members.items[position] = member;
            }
        }
    }

    fn anyLoading(self: *const Set) bool {
        for (self.members.items) |member| if (member.state == .loading) return true;
        return false;
    }
    fn faceStatusChanged(self: *Set, face: *Face) void {
        const index = self.indexOf(face.owner) orelse return;
        const had_loading = self.anyLoading();
        self.members.items[index].state = switch (face.status) {
            .unloaded => .idle,
            .loading => .loading,
            .loaded => .loaded,
            .failure => .failed,
        };
        if (!had_loading and face.status == .loading) {
            self.status = .loading;
            // §3.1 switch-to-loading step 3 replaces only a fulfilled ready.
            if (self.ready.fulfilled) {
                self.ready.deinit(self.owner, true);
                self.ready = .{ .slot = .{ .name = "FontFaceSet:ready" } };
                self.ready.ensure(self.owner) catch {};
            }
            self.queueEvent(.loading);
        }
        if (!self.anyLoading()) self.environmentChanged();
    }
    pub fn environmentChanged(self: *Set) void {
        if (self.retired) return;
        self.environment_pending = true;
        const document = self.liveDocument() orelse return;
        const style = hooks.engineOf(document) orelse return;
        const resources = style.ensureResourceState(document) catch return;
        resources.font_set = self.owner;
        resources.font_set_generation = self.generation;
        resources.font_interested = self.members.items.len != 0;
        resources.pending = true;
        @import("../window_documents.zig").requestRendering(document);
    }
    pub fn environmentReady(self: *Set) void {
        if (self.retired or self.anyLoading()) return;
        if (self.liveDocument()) |document| {
            // Font Loading 3 §3, pending on the environment. Browser probe
            // 2026-10-22 (Q50; integrator-probes-1022b/results/ready-*.json):
            // Chrome/Safari wait for window load; Firefox allows interactive.
            // Follow the observed majority, including an unrelated slow img.
            if ((interfaces.Document.get_readyState(document) catch return) != ._complete_) return;
            if (@import("../style_sheet_owners.zig").delaysLoadEvent(document)) return;
            if (@import("resource_loading.zig").hasPending(document)) return;
        }
        self.environment_pending = false;
        const was_loading = self.status == .loading;
        self.status = .loaded;
        self.ready.settle(self.owner, .{ .instance = self.owner }, false) catch return;
        if (was_loading) self.queueEvent(.done);
    }
    fn queueEvent(self: *Set, kind: EventTask.Kind) void {
        if (self.retired or !self.ownerLive()) return;
        const loop = self.realm.getOptionalEventLoop() orelse return;
        const task = self.allocator.create(EventTask) catch return;
        task.* = .{ .allocator = self.allocator, .target = InstanceLink.to(self.owner), .kind = kind };
        engine.keepPlatformObjectAlive(self.owner);
        const document = self.liveDocument();
        loop.queueTask(.{ .callback = EventTask.run, .drop = EventTask.drop, .context = task, .document = document, .document_generation = if (document) |doc| runtime.SlabAllocator.generationOf(doc) else 0 });
    }
    const EventTask = struct {
        allocator: Allocator,
        target: InstanceLink,
        kind: Kind,
        const Kind = enum { loading, done };
        fn run(context: ?*anyopaque) void {
            const self: *EventTask = @ptrCast(@alignCast(context orelse return));
            defer drop(self);
            if (!self.target.isLive()) return;
            const set = hooks.fontSetOf(self.target.instance) orelse return;
            if (set.retired) return;
            engine.runTaskInRealm(self.target.realm, steps, self) catch {};
        }
        fn steps(context: ?*anyopaque) void {
            const self: *EventTask = @ptrCast(@alignCast(context orelse return));
            const set = hooks.fontSetOf(self.target.instance) orelse return;
            if (self.kind == .loading) {
                set.fire("loading", &.{});
                return;
            }
            var loaded: std.ArrayList(InstanceLink) = .empty;
            defer loaded.deinit(self.allocator);
            var failed: std.ArrayList(InstanceLink) = .empty;
            defer failed.deinit(self.allocator);
            for (set.members.items) |*member| {
                if (!member.face.isLive()) continue;
                switch (member.state) {
                    .loaded => loaded.append(self.allocator, member.face) catch return,
                    .failed => failed.append(self.allocator, member.face) catch return,
                    else => continue,
                }
                member.state = .idle;
            }
            set.fire("loadingdone", loaded.items);
            // Dispatch can remove members or destroy a realm. The snapshots
            // are weak generation links; fire filters both life and membership.
            if (failed.items.len != 0 and self.target.isLive()) {
                const current = hooks.fontSetOf(self.target.instance) orelse return;
                if (!current.retired) current.fire("loadingerror", failed.items);
            }
        }
        fn drop(context: ?*anyopaque) void {
            const self: *EventTask = @ptrCast(@alignCast(context orelse return));
            if (self.target.isLive()) engine.releasePlatformObject(self.target.instance);
            self.allocator.destroy(self);
        }
    };
    fn fire(self: *Set, name: []const u8, candidates: []const InstanceLink) void {
        var members: std.ArrayList(*runtime.Instance) = .empty;
        defer members.deinit(self.allocator);
        for (candidates) |face| if (face.isLive() and self.indexOf(face.instance) != null) {
            members.append(self.allocator, face.instance) catch return;
        };
        const event = interfaces.FontFaceSetLoadEvent.call_constructor(self.realm, .initInterned(name), .{ .was_passed = true, .value = .{ .base = .{}, .fontfaces = members.items } }) catch return;
        const generation = runtime.SlabAllocator.generationOf(event);
        defer event.releaseIfUnwrapped(generation);
        _ = @import("../fire_event.zig").dispatchTrusted(self.owner, event) catch {};
    }
};
