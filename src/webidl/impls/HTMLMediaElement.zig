//! HTML media loading and resource selection. The host owns decoding; default
//! support is empty. Every asynchronous continuation is fenced by its load ID.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const webidl = @import("webidl");
const dom = @import("dom");
const html = @import("html");
const common = html.media_runtime;
const LoadState = @import("html_core").media.LoadState;
const backend = @import("platform").media_backend;
const same_object = @import("same_object.zig");
const hooks = dom.media_elements;
pub const State = interfaces.HTMLMediaElement.State;
const Kind = enum(u16) { event, failure, read, next_source, release_delay, pause, track_event, select_tracks, track_change, progress_tick, stalled, fatal_network, fatal_decode };

pub const InternalState = struct {
    activity: common.Activity,
    resource: common.Resource,
    load: LoadState,
    src_url: ?[]const u8 = null,
    src_object: ?typedefs.MediaProvider = null,
    object_edge: same_object.Traced = .{ .slot = .{ .name = "srcObject" } },
    error_object: ?*runtime.Instance = null,
    error_edge: same_object.Traced = .{ .slot = .{ .name = "error" } },
    before: ?same_object.Link = null,
    after: ?same_object.Link = null,
    candidate: ?same_object.Link = null,
    decoder: ?backend.Decoder = null,
    pending_play: std.ArrayList(engine.PromiseCapability) = .empty,
    read_queued: bool = false,
    volume: f64 = 1,
    muted: ?bool = null,
    preserves_pitch: bool = true,
    delay_document: ?same_object.Link = null,
    progress: @import("html_core").media.Progress = .{},
    progress_timer: @import("html_core").media.Deadline(runtime.TimerInterface) = .{},
    stall_timer: @import("html_core").media.Deadline(runtime.TimerInterface) = .{},
    text_tracks: ?*runtime.Instance = null,
    tracks_keep: same_object.KeptChild = .{},
    tracks: @import("html_core").media.track_selection.State = .{},
    fetch_document: ?same_object.Link = null,
    document_abort_pending: ?u64 = null,

    fn queue(self: *InternalState, kind: Kind, target: ?*runtime.Instance, name: ?[]const u8) !void {
        return self.activity.queue(@intFromEnum(kind), self.load.generation, target, name);
    }
    fn event(self: *InternalState, name: []const u8) !void {
        _ = try self.queue(.event, null, name);
    }
    fn endFetch(self: *InternalState) void {
        self.document_abort_pending = null;
        self.progress_timer.cancel();
        self.stall_timer.cancel();
        self.progress.reset();
        self.resource.stop();
        if (self.decoder) |*decoder| decoder.deinit();
        self.decoder = null;
        self.activity.fetching = false;
        self.read_queued = false;
    }
    fn syncDelay(self: *InternalState) void {
        const instance = self.activity.instance orelse return;
        if (self.load.delaying_load_event) {
            if (self.delay_document == null) if (common.documentOf(instance)) |doc| {
                self.delay_document = same_object.Link.to(doc);
            };
        } else if (self.delay_document) |link| {
            self.delay_document = null;
            if (link.isLive()) dom.document_lifecycle.loadDelayMayHaveEnded(link.instance);
        }
    }
    fn register(self: *InternalState) !void {
        const instance = self.activity.instance orelse return error.InvalidStateError;
        if (common.liveRegistry(instance.ctx)) |registry| try registry.add(instance, instance.ctx);
    }
    fn unregister(self: *InternalState) void {
        const instance = self.activity.instance orelse return;
        if (common.liveRegistry(instance.ctx)) |registry| registry.remove(instance);
    }
    fn finish(self: *InternalState, generation: u64) void {
        if (generation != self.load.generation) return;
        self.endFetch();
        self.load.endLoadDelay(generation);
        self.unregister();
        self.syncDelay();
        self.activity.sync();
    }
    fn cancel(self: *InternalState) void {
        self.activity.discardTasks(false);
        self.tracks.takeChange();
        self.load.cancel();
        self.endFetch();
        self.unregister();
        self.syncDelay();
        for (self.pending_play.items) |*promise| engine.releasePromiseCapability(promise);
        self.pending_play.clearRetainingCapacity();
        self.activity.sync();
    }
    fn selectLater(self: *InternalState) !void {
        const generation = self.load.beginSelection();
        self.syncDelay();
        try self.register();
        try self.activity.stable(generation, stable);
    }
    fn resumeSelection(self: *InternalState) !void {
        // Children steps 22–25 resume ONE waiting algorithm. Multiple child
        // insertions before its stable section cannot advance its pointer twice.
        // Step 24 can delay document load again, so restore the live registry.
        try self.register();
        if (self.activity.hasStable(self.load.generation)) return;
        try self.activity.stable(self.load.generation, stable);
    }
    fn fail(self: *InternalState) void {
        if (self.load.ready != .nothing) {
            self.fatal(.fatal_network);
            return;
        }
        self.endFetch();
        switch (self.load.failCandidate(self.load.generation)) {
            .fetch => unreachable,
            .ignored => {},
            .source_error => {
                const target = if (self.candidate) |link| (if (link.isLive()) link.instance else null) else null;
                // Children steps 10–11: error belongs to the source, then await
                // stable state before advancing the live child-list pointer.
                _ = self.queue(.next_source, target, if (target != null) "error" else null) catch {
                    self.cancel();
                    return;
                };
            },
            .dedicated_failure => {
                self.activity.queuePlay(@intFromEnum(Kind.failure), self.load.generation, "error", &self.pending_play, "NotSupportedError") catch {
                    self.cancel();
                    return;
                };
            },
        }
        self.activity.sync();
    }
    fn fatal(self: *InternalState, kind: Kind) void {
        self.endFetch();
        self.queue(kind, null, "error") catch self.cancel();
        self.activity.sync();
    }
    fn armProgress(self: *InternalState) !void {
        const instance = self.activity.instance orelse return;
        const timer = instance.ctx.getOptionalTimer() orelse return;
        try self.progress_timer.start(self.load.allocator, timer, 350, progressDue, self);
    }
    fn armStall(self: *InternalState) !void {
        const instance = self.activity.instance orelse return;
        const timer = instance.ctx.getOptionalTimer() orelse return;
        try self.stall_timer.start(self.load.allocator, timer, 3000, stallDue, self);
    }
    fn progressDue(context: *anyopaque) void {
        const self: *InternalState = @ptrCast(@alignCast(context));
        if (!self.activity.fetching or self.activity.instance == null) return;
        if (self.progress.bytes_pending) self.queue(.progress_tick, null, "progress") catch self.cancel();
        if (self.activity.fetching) self.armProgress() catch self.cancel();
    }
    fn stallDue(context: *anyopaque) void {
        const self: *InternalState = @ptrCast(@alignCast(context));
        if (self.activity.fetching and self.activity.instance != null) self.queue(.stalled, null, "stalled") catch self.cancel();
    }
    fn candidateResult(self: *InternalState, result: LoadState.CandidateResult) !void {
        switch (result) {
            .ignored => {},
            .fetch => try self.fetchCurrent(),
            .source_error, .dedicated_failure => {
                // candidate() already chose the failure branch; let fail() own
                // its task creation without changing which mode was selected.
                self.load.phase = .selecting;
                self.fail();
            },
        }
    }
    fn fetchCurrent(self: *InternalState) !void {
        const instance = self.activity.instance orelse return;
        var cors = try get_crossOrigin(instance);
        defer if (cors) |*value| value.deinit(instance.ctx.allocator);
        const setting = html.script_request.corsSettingFromAttribute(if (cors) |value| value.asSlice() else null);
        const destination: @import("fetch").internal.Destination = if (std.mem.eql(u8, instance.vtable.name, "HTMLAudioElement")) .audio else .video;
        const request = try common.requestFor(instance, self.load.currentSrc(), destination, setting);
        self.fetch_document = if (common.documentOf(instance)) |document| same_object.Link.to(document) else null;
        self.activity.fetching = true;
        self.activity.sync();
        self.resource.start(request) catch {
            self.fail();
            return;
        };
        try self.armProgress();
        try self.armStall();
    }
    fn queueRead(context: *anyopaque) void {
        const self: *InternalState = @ptrCast(@alignCast(context));
        if (self.read_queued or self.activity.instance == null) return;
        self.read_queued = true;
        _ = self.queue(.read, null, null) catch self.cancel();
    }
    fn read(self: *InternalState) !void {
        while (try self.resource.next()) |piece| {
            switch (piece) {
                .headers => |response| {
                    if (response.response_type == .@"error" or response.status < 200 or response.status >= 300) {
                        self.fail();
                        return;
                    }
                    const mime = (try @import("fetch").internal.mime.extractMimeEssence(self.load.allocator, &response.header_list)) orelse try self.load.allocator.dupe(u8, "");
                    defer self.load.allocator.free(mime);
                    self.decoder = try common.forRealm(self.activity.instance.?.ctx).open(self.load.allocator, mime);
                },
                .bytes => |bytes| {
                    if (bytes.len != 0) {
                        self.progress.received();
                        try self.armStall();
                    }
                    if (self.decoder) |decoder| if (try self.decoded(decoder.push(bytes, false))) return;
                },
                .eof => {
                    if (self.decoder) |decoder| if (try self.decoded(decoder.push("", true))) return;
                    if (self.load.ready == .nothing) {
                        self.fail();
                        return;
                    }
                    self.load.suspendFetch(self.load.generation);
                    self.syncDelay();
                    try self.event("suspend");
                    self.finish(self.load.generation);
                    return;
                },
                .failed => {
                    self.fail();
                    return;
                },
            }
        }
    }
    fn decoded(self: *InternalState, result: backend.Result) !bool {
        switch (result) {
            .unsupported, .decode_error => {
                if (self.load.ready == .nothing) self.fail() else self.fatal(.fatal_decode);
                return true;
            },
            .need_more => {},
            .metadata, .current_data => |metadata| {
                self.load.duration = metadata.duration;
                if (self.load.ready == .nothing) {
                    self.load.ready = .metadata;
                    try self.event("durationchange");
                    try self.event("loadedmetadata");
                }
                if (result == .current_data and self.load.ready == .metadata) {
                    self.load.haveCurrentData(self.load.generation);
                    self.syncDelay();
                    try self.event("loadeddata");
                }
            },
        }
        return false;
    }
};

fn data(instance: *runtime.Instance) *InternalState {
    return instance.getState(State).own._internal.?;
}
fn abortOwner(context: *anyopaque) void {
    const self: *InternalState = @ptrCast(@alignCast(context));
    self.cancel();
}
fn freeOwner(context: *anyopaque) void {
    const self: *InternalState = @ptrCast(@alignCast(context));
    self.resource.stop();
    self.load.deinit();
    if (self.src_url) |url| self.load.allocator.free(url);
    self.pending_play.deinit(self.load.allocator);
    self.activity.microtasks.deinit(self.load.allocator);
    self.load.allocator.destroy(self);
}
pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.HTMLElement.initWithState(allocator, StateType, vtable, ctx);
    instance.getState(State).own._internal = null;
    errdefer instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
    const self = try allocator.create(InternalState);
    self.* = .{ .activity = .{ .allocator = allocator, .instance = instance, .owner = self, .run = runTask, .abort = abortOwner, .free = freeOwner }, .resource = .{ .allocator = allocator, .ctx = ctx, .owner = self, .notify = InternalState.queueRead }, .load = LoadState.init(allocator) };
    instance.getState(State).own._internal = self;
    return instance;
}
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |self| {
        state.own._internal = null;
        self.cancel();
        self.object_edge.release(instance);
        self.error_edge.release(instance);
        if (self.text_tracks) |list| self.tracks_keep.release(list, severList);
        self.activity.detach();
        self.activity.maybeFree();
    }
    interfaces.HTMLElement.deinit(instance);
}
pub fn installHooks() void {
    dom.attribute_change_steps.install("audio", attributeChanged);
    dom.attribute_change_steps.install("video", attributeChanged);
    dom.media_elements.installMediaElement(delaysLoad, trackParentChanged, trackModeChanged);
    dom.mutation.registerInsertionStepsCallback(inserted) catch @panic("media insertion hook allocation");
    dom.mutation.registerRemovingStepsCallback(removed) catch @panic("media removing hook allocation");
    dom.document_fetches.install(.{ .discard = cancelRealm, .prepare_abort = prepareDocumentAbort, .abort = abortDocument });
    dom.unloading_cleanup.install(cancelRealm);
}
fn cancelRealm(ctx: runtime.Context) void {
    const registry = common.liveRegistry(ctx) orelse return;
    var index = registry.entries.len;
    while (index > 0) {
        index -= 1;
        if (index >= registry.entries.len) continue;
        const entry = registry.entries.get(index).?;
        if (entry.realm != @as(*anyopaque, @ptrCast(ctx))) continue;
        const instance: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
        if (common.isMedia(instance)) data(instance).cancel();
    }
}
fn prepareDocumentAbort(document: *runtime.Instance) bool {
    const registry = common.liveRegistry(document.ctx) orelse return false;
    var canceled = false;
    for (registry.entries.toSlice()) |entry| {
        const instance: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
        if (!common.isMedia(instance)) continue;
        const self = data(instance);
        const link = self.fetch_document orelse continue;
        if (!self.activity.fetching or link.instance != document or !link.isLive()) continue;
        self.document_abort_pending = self.load.generation;
        canceled = true;
    }
    return canceled;
}
fn abortDocument(document: *runtime.Instance) void {
    const registry = common.liveRegistry(document.ctx) orelse return;
    while (true) {
        const self: *InternalState = blk: {
            for (registry.entries.toSlice()) |entry| {
                const instance: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
                if (!common.isMedia(instance)) continue;
                const candidate = data(instance);
                const link = candidate.fetch_document orelse continue;
                if (candidate.document_abort_pending != null and link.instance == document and link.isLive()) break :blk candidate;
            }
            return;
        };
        const generation = self.document_abort_pending.?;
        self.document_abort_pending = null;
        if (generation != self.load.generation or !self.activity.fetching) continue;
        const instance = self.activity.instance orelse continue;
        engine.runInRealm(instance.ctx, documentAbortSteps, self) catch self.cancel();
    }
}
fn documentAbortSteps(context: ?*anyopaque) void {
    const self: *InternalState = @ptrCast(@alignCast(context.?));
    const instance = self.activity.instance orelse return;
    // User-aborted media fetching, steps 1–6. Only resource tasks are
    // invalidated; text-track list notifications are independent of this load.
    var task = self.activity.head;
    while (task) |pending| : (task = pending.next) {
        if (pending.resource_bound) pending.cancelled = true;
    }
    self.endFetch();
    self.load.cancel();
    self.load.error_code = .aborted;
    self.load.phase = .failed;
    const object = hooks.createError(instance.ctx, .aborted) catch {
        self.cancel();
        return;
    };
    self.error_object = object;
    self.error_edge.hold(instance, object);
    self.event("abort") catch {
        self.cancel();
        return;
    };
    if (self.load.ready == .nothing) {
        self.load.network = .empty;
        self.load.show_poster = true;
        self.event("emptied") catch {
            self.cancel();
            return;
        };
    } else self.load.network = .idle;
    self.unregister();
    self.syncDelay();
    self.activity.sync();
}
fn delaysLoad(document: *runtime.Instance) bool {
    const registry = common.liveRegistry(document.ctx) orelse return false;
    for (registry.entries.toSlice()) |entry| {
        const instance: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
        if (common.isMedia(instance) and common.documentOf(instance) == document and data(instance).load.delaying_load_event) return true;
    }
    return false;
}
fn attributeChanged(instance: *runtime.Instance, name: []const u8, _: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    if (namespace != null or !std.mem.eql(u8, name, "src") or value == null) return;
    const self = data(instance);
    const url = if (value.?.len != 0) html.encoding_parse.encodingParseAndSerialize(instance, value.?) catch null else null;
    if (self.src_url) |old| self.load.allocator.free(old);
    self.src_url = url;
    call_load(instance) catch self.cancel();
}
fn child(instance: *runtime.Instance, first: bool) ?*runtime.Instance {
    return if (first) interfaces.Node.get_firstChild(instance) catch null else interfaces.Node.get_nextSibling(instance) catch null;
}
fn parent(instance: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Node.get_parentNode(instance) catch null;
}
fn isSource(instance: *runtime.Instance) bool {
    return std.mem.eql(u8, instance.vtable.name, "HTMLSourceElement");
}
fn firstSource(instance: *runtime.Instance) ?*runtime.Instance {
    var cursor = child(instance, true);
    while (cursor) |node| : (cursor = child(node, false)) if (isSource(node)) return node;
    return null;
}
fn setCursor(self: *InternalState, before: ?*runtime.Instance, after: ?*runtime.Instance) void {
    self.before = if (before) |node| same_object.Link.to(node) else null;
    self.after = if (after) |node| same_object.Link.to(node) else null;
    const instance = self.activity.instance orelse return;
    if (before) |node| engine.traceChild(instance, node, .{ .name = "sourceBefore" }) else engine.forgetTracedChild(instance, .{ .name = "sourceBefore" });
    if (after) |node| engine.traceChild(instance, node, .{ .name = "sourceAfter" }) else engine.forgetTracedChild(instance, .{ .name = "sourceAfter" });
}
fn nextSource(self: *InternalState) ?*runtime.Instance {
    const instance = self.activity.instance orelse return null;
    var cursor = if (self.before) |link| (if (link.isLive() and parent(link.instance) == instance) child(link.instance, false) else child(instance, true)) else child(instance, true);
    while (cursor) |node| : (cursor = child(node, false)) {
        setCursor(self, node, child(node, false));
        if (isSource(node)) return node;
    }
    return null;
}
fn inserted(node: *dom.NodeBase) void {
    const instance = dom.instance_bridge.getInstanceTyped(runtime.Instance, node) orelse return;
    if (common.isMedia(instance)) {
        if (data(instance).load.network == .empty) data(instance).selectLater() catch data(instance).cancel();
        return;
    }
    const owner = parent(instance) orelse return;
    if (!common.isMedia(owner)) return;
    const self = data(owner);
    if (self.load.mode == .children) {
        const before = if (self.before) |link| (if (link.isLive()) link.instance else null) else null;
        if ((interfaces.Node.get_previousSibling(instance) catch null) == before) setCursor(self, before, instance);
    }
    if (!isSource(instance)) return;
    if (self.load.network == .empty) self.selectLater() catch self.cancel() else if (self.load.phase == .waiting) self.resumeSelection() catch self.cancel();
}
fn removed(node: *dom.NodeBase, old_parent: ?*dom.NodeBase) void {
    const instance = dom.instance_bridge.getInstanceTyped(runtime.Instance, node) orelse return;
    if (common.isMedia(instance)) {
        data(instance).cancel();
        return;
    }
    const old = old_parent orelse return;
    const owner = dom.instance_bridge.getInstanceTyped(runtime.Instance, old) orelse return;
    if (!common.isMedia(owner)) return;
    const self = data(owner);
    if (self.before) |link| if (link.instance == instance) {
        const after = if (self.after) |a| (if (a.isLive() and parent(a.instance) == owner) a.instance else null) else null;
        const before = if (after) |a| interfaces.Node.get_previousSibling(a) catch null else interfaces.Node.get_lastChild(owner) catch null;
        setCursor(self, before, after);
        return;
    };
    if (self.after) |link| if (link.instance == instance) {
        const before = if (self.before) |b| (if (b.isLive()) b.instance else null) else null;
        setCursor(self, before, if (before) |b| child(b, false) else child(owner, true));
    };
}
fn stable(context: *anyopaque, generation: u64) void {
    const self: *InternalState = @ptrCast(@alignCast(context));
    if (generation != self.load.generation) return;
    selection(self) catch self.cancel();
}
fn selection(self: *InternalState) !void {
    const instance = self.activity.instance orelse return;
    const generation = self.load.generation;
    if (self.load.phase == .stable_state) {
        const mode = self.load.select(generation, .{ .provider_object = self.src_object != null, .src_attribute = try interfaces.Element.call_hasAttribute(instance, .initInterned("src")), .source_child = firstSource(instance) != null }, true) orelse return;
        self.syncDelay();
        if (mode == .none) {
            self.finish(generation);
            return;
        }
        try self.event("loadstart");
        switch (mode) {
            .object => {
                self.fail();
                return;
            },
            .attribute => {
                try self.candidateResult(try self.load.candidate(generation, .{ .url = self.src_url }));
                return;
            },
            .children => setCursor(self, null, child(instance, true)),
            .none => unreachable,
        }
    }
    if (self.load.mode != .children) return;
    const candidate = nextSource(self);
    if (self.load.phase == .next_candidate or self.load.phase == .waiting) {
        _ = self.load.nextCandidate(generation, candidate != null, true);
        self.syncDelay();
    } else if (candidate == null) {
        self.load.phase = .next_candidate;
        _ = self.load.nextCandidate(generation, false, true);
    }
    const source = candidate orelse {
        _ = try self.queue(.release_delay, null, null);
        return;
    };
    self.candidate = same_object.Link.to(source);
    engine.traceChild(instance, source, .{ .name = "sourceCandidate" });
    var type_value = try interfaces.HTMLSourceElement.get_type(source);
    defer type_value.deinit(source.ctx.allocator);
    var unsupported = false;
    if (try @import("mimesniff").parseMimeType(self.load.allocator, type_value.asSlice())) |parsed| {
        var mime = parsed;
        defer mime.deinit();
        unsupported = (try call_canPlayType(instance, type_value)) == .__;
    }
    var media = try interfaces.HTMLSourceElement.get_media(source);
    defer media.deinit(source.ctx.allocator);
    var matches = true;
    if (media.len() != 0) if (common.globalOf(instance.ctx)) |window| {
        const query = try interfaces.Window.call_matchMedia(window, media);
        defer query.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(query));
        matches = try interfaces.MediaQueryList.get_matches(query);
    };
    try self.candidateResult(try self.load.candidate(generation, .{ .url = hooks.sourceURL(source), .media_matches = matches, .known_unsupported_type = unsupported }));
}
fn runTask(context: *anyopaque, task: *common.Task) void {
    const self: *InternalState = @ptrCast(@alignCast(context));
    const kind: Kind = @enumFromInt(task.kind);
    // Track list membership is independent of the current media resource.
    if (kind == .track_event) {
        if (task.event) |event| event.dispatch();
        return;
    }
    if (kind == .select_tracks) {
        selectTracks(self) catch {};
        return;
    }
    if (kind == .track_change) {
        self.tracks.takeChange();
        if (task.event) |event| event.dispatch();
        return;
    }
    if (task.generation != self.load.generation) return;
    const instance = self.activity.instance orelse return;
    switch (kind) {
        .track_event, .select_tracks, .track_change => unreachable,
        .progress_tick => {
            if (self.activity.fetching and self.progress.takeProgress()) {
                self.load.stalled = false;
                if (task.event) |event| event.dispatch();
            }
        },
        .stalled => {
            if (self.activity.fetching and self.progress.takeStalled()) {
                self.load.stalled = true;
                if (task.event) |event| event.dispatch();
            }
        },
        .fatal_network, .fatal_decode => {
            const code: hooks.ErrorCode = if (kind == .fatal_network) .network else .decode;
            self.load.fatalFailure(task.generation, if (kind == .fatal_network) .network else .decode);
            self.syncDelay();
            const object = hooks.createError(instance.ctx, code) catch {
                self.cancel();
                return;
            };
            self.error_object = object;
            self.error_edge.hold(instance, object);
            if (task.event) |event| event.dispatch();
            self.finish(task.generation);
        },
        .event => if (task.event) |event| event.dispatch(),
        .read => {
            self.read_queued = false;
            self.read() catch self.fail();
        },
        .failure => {
            if (!self.load.runDedicatedFailure(task.generation)) return;
            const error_object = hooks.createError(instance.ctx, .source_not_supported) catch {
                self.cancel();
                return;
            };
            self.error_object = error_object;
            self.error_edge.hold(instance, error_object);
            if (task.event) |event| event.dispatch();
            task.rejectPromises("NotSupportedError");
            self.finish(task.generation);
        },
        .next_source => {
            if (task.event) |event| event.dispatch();
            if (task.generation == self.load.generation) {
                // Children steps 10–11: the error task kept the failed source
                // through script; selection now needs only its list position.
                // A removed candidate must not stay alive while we wait.
                self.candidate = null;
                engine.forgetTracedChild(instance, .{ .name = "sourceCandidate" });
                self.activity.stable(task.generation, stable) catch self.cancel();
            }
        },
        .release_delay => {
            // Children step 20 changes only the delay flag. A new source may
            // have resumed this generation before the queued task runs; it
            // must not terminate that fetch or remove its live registration.
            self.load.endLoadDelay(task.generation);
            self.syncDelay();
            if (self.load.phase == .waiting and !self.activity.fetching) self.unregister();
            self.activity.sync();
        },
        .pause => {
            if (task.event) |event| event.dispatch();
            task.rejectPromises("AbortError");
        },
    }
}

pub fn call_load(instance: *runtime.Instance) anyerror!void {
    const self = data(instance);
    // Load steps 1–5: settle queued play outcomes before invalidating tasks.
    self.activity.discardTasks(true);
    self.endFetch();
    self.unregister();
    const reset = self.load.beginLoad();
    self.syncDelay();
    self.error_object = null;
    self.error_edge.release(instance);
    setCursor(self, null, null);
    self.candidate = null;
    engine.forgetTracedChild(instance, .{ .name = "sourceCandidate" });
    // Steps 6–10: old resource event order, then the stable selection section.
    if (reset.queue_abort) try self.event("abort");
    if (reset.queue_emptied) try self.event("emptied");
    if (reset.reject_play_with_abort) try rejectPending(self, "AbortError");
    if (reset.queue_timeupdate) try self.event("timeupdate");
    if (reset.queue_ratechange) try self.event("ratechange");
    try self.register();
    try self.activity.stable(reset.generation, stable);
}
fn rejectPending(self: *InternalState, name: []const u8) !void {
    const exception = try engine.createDOMException(self.activity.instance.?.ctx, name, "");
    defer exception.release();
    for (self.pending_play.items) |*promise| {
        engine.rejectPromise(promise, exception.value) catch {};
        engine.releasePromiseCapability(promise);
    }
    self.pending_play.clearRetainingCapacity();
}
pub fn call_play(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const self = data(instance);
    if (self.load.error_code == .source_not_supported) {
        const exception = try engine.createDOMException(instance.ctx, "NotSupportedError", "");
        defer exception.release();
        return (try engine.createRejectedPromise(instance.ctx, exception.value)).take();
    }
    var promise = try engine.createPromise(instance.ctx);
    errdefer engine.releasePromiseCapability(&promise);
    const result = try engine.retainValue(instance.ctx, promise.promise);
    errdefer result.release();
    try self.pending_play.append(self.load.allocator, promise);
    if (self.load.network == .empty) self.selectLater() catch self.cancel();
    if (self.load.paused) {
        self.load.paused = false;
        self.event("play") catch self.cancel();
        self.event("waiting") catch self.cancel();
    }
    self.load.can_autoplay = false;
    return result.take();
}
pub fn call_pause(instance: *runtime.Instance) anyerror!void {
    const self = data(instance);
    if (self.load.network == .empty) try self.selectLater();
    self.load.can_autoplay = false;
    if (self.load.paused) return;
    self.load.paused = true;
    try self.event("timeupdate");
    try self.activity.queuePlay(@intFromEnum(Kind.pause), self.load.generation, "pause", &self.pending_play, "AbortError");
}
pub fn call_canPlayType(instance: *runtime.Instance, mime: runtime.DOMString) anyerror!enums.CanPlayTypeResult {
    return switch (common.forRealm(instance.ctx).canPlayType(mime.asSlice())) {
        .unsupported => .__,
        .maybe => ._maybe_,
        .probably => ._probably_,
    };
}
pub fn get_error(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return data(instance).error_object;
}
pub fn get_currentSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    return instance.ctx.allocator.dupe(u8, data(instance).load.currentSrc());
}
pub fn get_networkState(instance: *runtime.Instance) anyerror!u16 {
    return @intFromEnum(data(instance).load.network);
}
pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
    return @intFromEnum(data(instance).load.ready);
}
pub fn get_paused(instance: *runtime.Instance) anyerror!bool {
    return data(instance).load.paused;
}
pub fn get_seeking(instance: *runtime.Instance) anyerror!bool {
    return data(instance).load.seeking;
}
pub fn get_ended(_: *runtime.Instance) anyerror!bool {
    return false;
}
pub fn get_duration(instance: *runtime.Instance) anyerror!f64 {
    return data(instance).load.duration;
}
pub fn get_currentTime(instance: *runtime.Instance) anyerror!f64 {
    const load = &data(instance).load;
    return if (load.ready == .nothing) load.default_start_position else load.official_position;
}
pub fn set_currentTime(instance: *runtime.Instance, value: f64) anyerror!void {
    const load = &data(instance).load;
    if (load.ready == .nothing) load.default_start_position = value else {
        load.position = value;
        load.official_position = value;
    }
}
pub fn get_buffered(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.TimeRanges.init(instance.ctx.allocator, instance.ctx);
}
pub fn get_seekable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.TimeRanges.init(instance.ctx.allocator, instance.ctx);
}
pub fn get_played(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.TimeRanges.init(instance.ctx.allocator, instance.ctx);
}
pub fn get_volume(instance: *runtime.Instance) anyerror!f64 {
    return data(instance).volume;
}
pub fn set_volume(instance: *runtime.Instance, value: f64) anyerror!void {
    if (value < 0 or value > 1) return error.IndexSizeError;
    const self = data(instance);
    if (self.volume == value) return;
    self.volume = value;
    try self.event("volumechange");
}
pub fn get_muted(instance: *runtime.Instance) anyerror!bool {
    return data(instance).muted orelse try interfaces.HTMLMediaElement.get_defaultMuted(instance);
}
pub fn set_muted(instance: *runtime.Instance, value: bool) anyerror!void {
    const previous = try get_muted(instance);
    data(instance).muted = value;
    if (previous != value) try data(instance).event("volumechange");
}
pub fn get_defaultPlaybackRate(instance: *runtime.Instance) anyerror!f64 {
    return data(instance).load.default_playback_rate;
}
pub fn set_defaultPlaybackRate(instance: *runtime.Instance, value: f64) anyerror!void {
    if (data(instance).load.default_playback_rate == value) return;
    data(instance).load.default_playback_rate = value;
    try data(instance).event("ratechange");
}
pub fn get_playbackRate(instance: *runtime.Instance) anyerror!f64 {
    return data(instance).load.playback_rate;
}
pub fn set_playbackRate(instance: *runtime.Instance, value: f64) anyerror!void {
    if (data(instance).load.playback_rate == value) return;
    data(instance).load.playback_rate = value;
    try data(instance).event("ratechange");
}
pub fn get_preservesPitch(instance: *runtime.Instance) anyerror!bool {
    return data(instance).preserves_pitch;
}
pub fn set_preservesPitch(instance: *runtime.Instance, value: bool) anyerror!void {
    data(instance).preserves_pitch = value;
}
pub fn get_srcObject(instance: *runtime.Instance) anyerror!?typedefs.MediaProvider {
    return data(instance).src_object;
}
pub fn set_srcObject(instance: *runtime.Instance, value: ?typedefs.MediaProvider) anyerror!void {
    const self = data(instance);
    self.src_object = value;
    if (value) |provider| {
        const object = switch (provider) {
            inline else => |object| object,
        };
        self.object_edge.hold(instance, object);
    } else self.object_edge.release(instance);
    try call_load(instance);
}
pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    var value = (try interfaces.Element.call_getAttribute(instance, .initInterned("crossorigin"))) orelse return null;
    defer value.deinit(instance.ctx.allocator);
    return .initInterned(if (std.ascii.eqlIgnoreCase(value.asSlice(), "use-credentials")) "use-credentials" else "anonymous");
}
pub fn set_crossOrigin(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    if (value) |text| try interfaces.Element.call_setAttribute(instance, .initInterned("crossorigin"), .{ .domstring = text }) else try interfaces.Element.call_removeAttribute(instance, .initInterned("crossorigin"));
}
pub fn get_preload(instance: *runtime.Instance) anyerror!runtime.DOMString {
    var value = (try interfaces.Element.call_getAttribute(instance, .initInterned("preload"))) orelse return .initInterned("metadata");
    defer value.deinit(instance.ctx.allocator);
    if (std.ascii.eqlIgnoreCase(value.asSlice(), "none")) return .initInterned("none");
    if (std.ascii.eqlIgnoreCase(value.asSlice(), "metadata")) return .initInterned("metadata");
    return .initInterned("auto");
}
pub fn set_preload(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, .initInterned("preload"), .{ .domstring = value });
}
pub fn call_fastSeek(instance: *runtime.Instance, time: f64) anyerror!void {
    try set_currentTime(instance, time);
}

pub fn get_audioTracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

pub fn get_videoTracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

pub fn get_textTracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const self = data(instance);
    if (self.text_tracks == null) {
        const list = try hooks.createTextTrackList(instance.ctx);
        self.text_tracks = list;
        self.tracks_keep.made(list);
    }
    const list = self.text_tracks.?;
    self.tracks_keep.handOut(instance, list, .{ .name = "textTracks" });
    return list;
}

pub fn get_sinkId(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

pub fn get_remote(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

pub fn get_disableRemotePlayback(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

pub fn get_mediaKeys(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

pub fn get_onencrypted(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

pub fn get_onwaitingforkey(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

pub fn set_disableRemotePlayback(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

pub fn set_onencrypted(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

pub fn set_onwaitingforkey(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

pub fn call_setSinkId(instance: *runtime.Instance, sinkId: runtime.DOMString) anyerror!runtime.JSValue {
    _ = instance;
    _ = sinkId;
    return error.NotImplemented;
}

pub fn call_setMediaKeys(instance: *runtime.Instance, mediaKeys: ?*runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    _ = mediaKeys;
    return error.NotImplemented;
}

pub fn call_captureStream(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

pub fn call_getStartDate(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

pub fn call_addTextTrack(instance: *runtime.Instance, kind: enums.TextTrackKind, label: webidl.Opt(runtime.DOMString), language: webidl.Opt(runtime.DOMString)) anyerror!*runtime.Instance {
    _ = instance;
    _ = kind;
    _ = label;
    _ = language;
    return error.NotImplemented;
}

fn severList(_: *runtime.Instance) void {}
fn trackParentChanged(element: *runtime.Instance, old_parent: ?*runtime.Instance, new_parent: ?*runtime.Instance) void {
    const was_media = if (old_parent) |old| common.isMedia(old) else false;
    const is_media = if (new_parent) |new| common.isMedia(new) else false;
    if (!was_media and !is_media) return;
    const track = interfaces.HTMLTrackElement.get_track(element) catch return;
    if (old_parent) |old| if (common.isMedia(old)) {
        const list = get_textTracks(old) catch return;
        hooks.removeTextTrack(list, track);
        if (old.ctx.hasEngine()) data(old).activity.queueTrack(@intFromEnum(Kind.track_event), 0, list, "removetrack", track) catch {};
    };
    if (new_parent) |media| if (common.isMedia(media)) {
        const list = get_textTracks(media) catch return;
        appendInTreeOrder(media, list, track) catch return;
        // Sourcing out-of-band tracks: selection task precedes addtrack.
        if (media.ctx.hasEngine()) {
            data(media).activity.queueIndependent(@intFromEnum(Kind.select_tracks), null, null) catch {};
            data(media).activity.queueTrack(@intFromEnum(Kind.track_event), 0, list, "addtrack", track) catch {};
        }
    };
}
fn appendInTreeOrder(media: *runtime.Instance, list: *runtime.Instance, added: *runtime.Instance) !void {
    // The list starts with child-track order; script-created tracks follow it.
    // Temporary holds protect every existing track across removal of its edge.
    const Held = struct { track: *runtime.Instance, hold: ?engine.Owned };
    var old: std.ArrayList(Held) = .empty;
    defer {
        for (old.items) |item| if (item.hold) |hold| hold.release();
        old.deinit(media.ctx.allocator);
    }
    const length = try interfaces.TextTrackList.get_length(list);
    try old.ensureTotalCapacity(media.ctx.allocator, length);
    for (0..length) |index| {
        const track = try interfaces.TextTrackList.call_getter(list, @intCast(index));
        const hold = if (media.ctx.hasEngine()) try engine.retainValue(media.ctx, .{ .instance = track }) else null;
        old.appendAssumeCapacity(.{ .track = track, .hold = hold });
    }
    for (old.items) |item| hooks.removeTextTrack(list, item.track);
    var cursor = child(media, true);
    while (cursor) |node| : (cursor = child(node, false)) if (std.mem.eql(u8, node.vtable.name, "HTMLTrackElement")) {
        try hooks.appendTextTrack(list, try interfaces.HTMLTrackElement.get_track(node));
    };
    try hooks.appendTextTrack(list, added);
    for (old.items) |item| try hooks.appendTextTrack(list, item.track);
}
fn trackModeChanged(media: *runtime.Instance) void {
    const self = data(media);
    if (!media.ctx.hasEngine()) return;
    const list = get_textTracks(media) catch return;
    // Mode-change steps 1–3: one notification until its task clears the flag.
    if (!self.tracks.requestChange()) return;
    self.activity.queueIndependent(@intFromEnum(Kind.track_change), list, "change") catch {
        self.tracks.takeChange();
    };
}
fn selectTracks(self: *InternalState) !void {
    if (self.tracks.blocked_on_parser or self.tracks.automatic_selected) return;
    const media = self.activity.instance orelse return;
    const list = try get_textTracks(media);
    const length = try interfaces.TextTrackList.get_length(list);
    // Honor user preferences steps 1–2. The host has no preference configured;
    // the spec's default-attribute branch chooses the first disabled default.
    for (0..2) |group| {
        var showing = false;
        for (0..length) |index| {
            const track = try interfaces.TextTrackList.call_getter(list, @intCast(index));
            const kind = try interfaces.TextTrack.get_kind(track);
            const matches = if (group == 0) kind == ._subtitles_ or kind == ._captions_ else kind == ._descriptions_;
            if (matches and (try interfaces.TextTrack.get_mode(track)) == ._showing_) showing = true;
        }
        if (showing) continue;
        var cursor = child(media, true);
        while (cursor) |node| : (cursor = child(node, false)) if (std.mem.eql(u8, node.vtable.name, "HTMLTrackElement")) {
            const track = try interfaces.HTMLTrackElement.get_track(node);
            const kind = try interfaces.TextTrack.get_kind(track);
            const matches = if (group == 0) kind == ._subtitles_ or kind == ._captions_ else kind == ._descriptions_;
            if (matches and (try interfaces.TextTrack.get_mode(track)) == ._disabled_ and (try interfaces.HTMLTrackElement.get_default(node))) {
                try interfaces.TextTrack.set_mode(track, ._showing_);
                break;
            }
        };
    }
    // Step 3: default chapter and metadata tracks are all enabled, hidden.
    var cursor = child(media, true);
    while (cursor) |node| : (cursor = child(node, false)) if (std.mem.eql(u8, node.vtable.name, "HTMLTrackElement")) {
        const track = try interfaces.HTMLTrackElement.get_track(node);
        const kind = try interfaces.TextTrack.get_kind(track);
        if ((kind == ._chapters_ or kind == ._metadata_) and (try interfaces.TextTrack.get_mode(track)) == ._disabled_ and (try interfaces.HTMLTrackElement.get_default(node))) try interfaces.TextTrack.set_mode(track, ._hidden_);
    };
    self.tracks.automatic_selected = true; // Step 4. Parser integration is deferred (Q19).
}
