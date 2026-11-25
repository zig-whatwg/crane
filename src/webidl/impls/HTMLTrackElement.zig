//! HTML 4.8.11.11.3: out-of-band text track processing.
//! The one text track format is WebVTT (html.webvtt, WebVTT 6.1-6.3): a
//! fetched resource is parsed once it has arrived, its cues become the text
//! track's list of cues (WebVTT 6.1 step 14.2: VTTCue objects, with VTTRegion
//! objects for the regions they are in), and a file that is successfully
//! processed makes the track loaded and fires `load`.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");
const common = html.media_runtime;
const hooks = dom.media_elements;
const same_object = @import("dom").same_object;
pub const State = interfaces.HTMLTrackElement.State;
/// `start`: the processing model's deferred steps 6-10 (`startSteps`); `read`:
/// a networking task reading the resource; `failure`: a failed-to-load task.
const Kind = enum(u16) { read, failure, start };
const webvtt = html.webvtt;
/// A block of the Browser's runtime arena (`arena`), registered in the
/// Browser's side table while its element lives: queued tasks may hold it
/// past its element's deinit (`common.Activity`), so the registry does not
/// own the block - `freeOwner` returns it, when the last of them lets go.
/// A track removed from its tree while script held no wrapper of it is an
/// orphan nothing deinits; its state is freed by the sweep at its Browser's
/// end (`sweepRemaining`, lane orphanleak).
pub const InternalState = struct {
    /// The arena the block came from: its element's Browser's.
    arena: *runtime.ArenaAllocator,
    activity: common.Activity,
    resource: common.Resource,
    track: ?*runtime.Instance = null,
    kept: same_object.KeptChild = .{},
    parent: ?same_object.Link = null,
    url: ?[]const u8 = null,
    selected_url: ?[]const u8 = null,
    generation: u64 = 0,
    processing: bool = false,
    waiting: bool = false,
    read_queued: bool = false,
    /// A `start` task is queued and has not run: the processing model is at
    /// its step 5, and reads the track URL only when that task runs.
    start_queued: bool = false,
    fetch_document: ?same_object.Link = null,
    document_abort_pending: ?u64 = null,
    /// The resource's bytes so far, for the WebVTT parser at its end
    /// (`activity.allocator`).
    body: std.ArrayListUnmanaged(u8) = .empty,

    fn enabled(self: *InternalState) bool {
        const track = self.track orelse return false;
        return (interfaces.TextTrack.get_mode(track) catch return false) != ._disabled_;
    }
    fn unregister(self: *InternalState) void {
        if (self.activity.instance) |instance| if (common.liveRegistry(instance.ctx)) |registry| {
            registry.remove(instance);
        };
    }
    fn stopFetch(self: *InternalState) void {
        self.document_abort_pending = null;
        self.body.clearAndFree(self.activity.allocator);
        self.resource.stop();
        self.activity.fetching = false;
        self.read_queued = false;
    }
    fn cancel(self: *InternalState) void {
        self.generation +%= 1;
        self.activity.discardTasks(false);
        self.stopFetch();
        self.processing = false;
        self.waiting = false;
        self.start_queued = false;
        self.unregister();
        self.activity.sync();
    }
    fn queue(self: *InternalState, kind: Kind) !void {
        _ = try self.activity.queue(@backingInt(kind), self.generation, null, "error");
    }
    fn start(self: *InternalState) !void {
        const instance = self.activity.instance orelse return;
        if (!self.enabled()) return; // Processing model step 2.
        if (!self.processing) {
            const owner = interfaces.Node.get_parentNode(instance) catch null;
            if (owner == null or !common.isMedia(owner.?)) return; // Step 3.
            self.processing = true;
            self.generation +%= 1;
            if (common.liveRegistry(instance.ctx)) |registry| try registry.add(instance, instance.ctx);
            try self.awaitTop();
        } else if (self.start_queued) {
            // Step 1: this occurrence is still at step 5, and its step 7
            // reads the track URL when it runs - a URL set or changed now is
            // the one it fetches. No fetch is ongoing, so there is nothing
            // for step 10 to abort (the track CORS tests set mode, then src,
            // in one script: Crane fired error before any request).
        } else if (!std.mem.eql(u8, self.url orelse "", self.selected_url orelse "") and (self.waiting or self.activity.fetching)) {
            // Step 10, only "while fetching is ongoing": the track URL
            // changed, or the mode became hidden or showing with the URL
            // changed - abort fetching, discard its pending tasks, and queue
            // the failed-to-load task. Or step 12, waiting: the URL is no
            // longer the one fetched while the mode is hidden or showing, so
            // step 13 jumps to top. A failure step 10 queued with no fetch
            // (an empty URL, no browsing context) is left to run; `failed`
            // then reaches step 12 with the changed URL.
            // The abort, as the browsers do it, differs in all three (lane
            // flk4's probe, 2026-11-23): Chrome 157 fires error and loads
            // the new URL; Firefox 159 fires error and never fetches the new
            // URL; Safari 27 fires no error and loads it. Golden rule 2,
            // mechanism by mechanism: error fired - Chrome and Firefox; the
            // new URL loaded - Chrome and Safari. Together that is Chrome's
            // shipping behaviour and the spec's steps here.
            self.generation +%= 1;
            self.activity.discardTasks(false);
            self.stopFetch();
            if (self.waiting) {
                self.waiting = false;
                if (common.liveRegistry(instance.ctx)) |registry| try registry.add(instance, instance.ctx);
                try self.awaitTop();
            } else try self.queue(.failure);
        }
    }
    /// Step 5, "Top: await a stable state", run as all three browsers run it:
    /// after the current task, not in a microtask. Chrome starts a zero-delay
    /// timer on the networking task runner (html_track_element.cc
    /// ScheduleLoad: "We use a timer to approximate a stable state"), Safari
    /// queues a media element task (HTMLTrackElement.cpp scheduleLoad), and
    /// Firefox runs it in nsContentUtils::RunInStableState, after the task
    /// (HTMLTrackElement.cpp MaybeDispatchLoadResource). Chrome 157, Firefox
    /// 159 and Safari 27 read readyState NONE two microtasks after a mode
    /// change, and fetch the URL set then (lane flk4's probe, 2026-11-23;
    /// tests/wpt/crane/flk4-track-src-after-mode.html). No newer spec is
    /// involved, so golden rule 2 takes the browsers' task; Crane queues an
    /// element task, Safari's model. Its steps are `startSteps`.
    fn awaitTop(self: *InternalState) !void {
        try self.activity.queue(@backingInt(Kind.start), self.generation, null, null);
        self.start_queued = true;
    }
    fn queueRead(context: *anyopaque) void {
        const self: *InternalState = @ptrCast(@alignCast(context));
        if (self.activity.instance == null or self.read_queued) return;
        self.read_queued = true;
        self.queue(.read) catch self.cancel();
    }
    /// Step 10, the resource fully fetched: passed to the WebVTT parser. A
    /// file that is not successfully processed fails in this networking task
    /// (`failed`); one that is makes the track loaded.
    fn processResource(self: *InternalState, task: *common.Task) void {
        var result = webvtt.parse(self.activity.allocator, self.body.items) catch return self.failed(task);
        defer result.deinit();
        if (!result.processed) return self.failed(task);
        // "The text track list of cues being used for that parser's output."
        addParsedCues(self.track.?, &result) catch return self.failed(task);
        self.loaded();
    }
    /// "If fetching does not fail, and the file was successfully processed,
    /// then the final task that is queued by the networking task source,
    /// after it has finished parsing the data, must change the text track
    /// readiness state to loaded, and fire an event named load at the track
    /// element." Then steps 11-12, as after a failure: wait for the URL to
    /// change while the track is enabled (`start`).
    fn loaded(self: *InternalState) void {
        const instance = self.activity.instance orelse return;
        self.stopFetch();
        hooks.setTrackReadiness(self.track.?, .loaded);
        self.waiting = true;
        self.unregister();
        const generation = self.generation;
        if (common.Event.init(instance, "load")) |event| {
            defer event.deinit();
            event.dispatch();
        } else |_| {}
        if (self.activity.instance == null or generation != self.generation) return;
        self.start() catch self.cancel();
        self.activity.sync();
    }
    fn failed(self: *InternalState, task: *common.Task) void {
        self.stopFetch();
        hooks.setTrackReadiness(self.track.?, .failed);
        self.waiting = true;
        self.unregister();
        // Error was fully initialized when the task was queued, before script.
        if (task.event) |event| event.dispatch();
        if (self.activity.instance == null or task.generation != self.generation) return;
        self.start() catch self.cancel();
        self.activity.sync();
    }
};
/// WebVTT 6.1 step 14.2, for each cue the parser made, in file order: a
/// VTTCue with its identifier, times, settings and cue text, in the region
/// object made for its WebVTT region (one VTTRegion per REGION block, shared
/// by the cues in it, kept by the track), added to `track`'s text track list
/// of cues - which owns it, with no wrapper, until script reads it
/// (TextTrackCueList.zig).
fn addParsedCues(track: *runtime.Instance, result: *const webvtt.Result) !void {
    const ctx = track.ctx;
    const allocator = ctx.allocator;
    const regions = try allocator.alloc(?*runtime.Instance, result.regions.len);
    defer allocator.free(regions);
    @memset(regions, null);
    // The cues made, added to the track together at the end.
    var made: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer made.deinit(allocator);
    try made.ensureTotalCapacity(allocator, result.cues.len);
    // Until then they are this function's: a failure frees them (none has a
    // wrapper).
    var handed = false;
    defer if (!handed) for (made.items) |cue| cue.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(cue));
    for (result.cues) |parsed| {
        const cue = try interfaces.VTTCue.init(allocator, ctx);
        made.appendAssumeCapacity(cue);
        try interfaces.TextTrackCue.set_id(cue, .initInterned(parsed.identifier));
        try interfaces.TextTrackCue.set_startTime(cue, parsed.start_time);
        try interfaces.TextTrackCue.set_endTime(cue, parsed.end_time);
        try interfaces.TextTrackCue.set_pauseOnExit(cue, parsed.pause_on_exit);
        if (parsed.region) |index| {
            if (regions[index] == null) {
                // A region no cue is in is never made; one made is the
                // track's from the start.
                const region = try regionObject(ctx, result.regions[index]);
                hooks.keepTrackRegion(track, region);
                regions[index] = region;
            }
            try interfaces.VTTCue.set_region(cue, regions[index]);
        }
        try interfaces.VTTCue.set_vertical(cue, switch (parsed.writing_direction) {
            .horizontal => .__,
            .vertical_growing_left => ._rl_,
            .vertical_growing_right => ._lr_,
        });
        try interfaces.VTTCue.set_snapToLines(cue, parsed.snap_to_lines);
        try interfaces.VTTCue.set_line(cue, switch (parsed.line) {
            .auto => .{ .auto_keyword = ._auto_ },
            .number => |number| .{ .double = number },
        });
        try interfaces.VTTCue.set_lineAlign(cue, switch (parsed.line_alignment) {
            .start => ._start_,
            .center => ._center_,
            .end => ._end_,
        });
        try interfaces.VTTCue.set_position(cue, switch (parsed.position) {
            .auto => .{ .auto_keyword = ._auto_ },
            .number => |number| .{ .double = number },
        });
        try interfaces.VTTCue.set_positionAlign(cue, switch (parsed.position_alignment) {
            .line_left => ._line_left_,
            .center => ._center_,
            .line_right => ._line_right_,
            .auto => ._auto_,
        });
        try interfaces.VTTCue.set_size(cue, parsed.size);
        try interfaces.VTTCue.set_align(cue, switch (parsed.text_alignment) {
            .start => ._start_,
            .center => ._center_,
            .end => ._end_,
            .left => ._left_,
            .right => ._right_,
        });
        try interfaces.VTTCue.set_text(cue, .initInterned(parsed.text));
    }
    handed = true;
    hooks.addTrackCues(track, made.items) catch |err| {
        // The cues the track's list did not take are still this function's.
        for (made.items) |cue| if ((interfaces.TextTrackCue.get_track(cue) catch null) == null) cue.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(cue));
        return err;
    };
}
/// The VTTRegion object for a parsed WebVTT region (6.1, region creation and
/// 6.2's settings).
fn regionObject(ctx: runtime.Context, parsed: webvtt.Region) !*runtime.Instance {
    const region = try interfaces.VTTRegion.init(ctx.allocator, ctx);
    errdefer region.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(region));
    try interfaces.VTTRegion.set_id(region, .initInterned(parsed.identifier));
    try interfaces.VTTRegion.set_width(region, parsed.width);
    try interfaces.VTTRegion.set_lines(region, parsed.lines);
    try interfaces.VTTRegion.set_regionAnchorX(region, parsed.anchor[0]);
    try interfaces.VTTRegion.set_regionAnchorY(region, parsed.anchor[1]);
    try interfaces.VTTRegion.set_viewportAnchorX(region, parsed.viewport_anchor[0]);
    try interfaces.VTTRegion.set_viewportAnchorY(region, parsed.viewport_anchor[1]);
    try interfaces.VTTRegion.set_scroll(region, switch (parsed.scroll) {
        .none => .__,
        .up => ._up_,
    });
    return region;
}
fn data(instance: *runtime.Instance) *InternalState {
    return instance.getState(State).own._internal.?;
}
pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.HTMLElement.initWithState(allocator, StateType, vtable, ctx);
    instance.getState(State).own._internal = null;
    errdefer instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
    const arena = runtime.arenaOf(instance);
    const self = try arena.create(InternalState);
    errdefer arena.destroy(InternalState, self);
    self.* = .{ .arena = arena, .activity = .{ .allocator = allocator, .instance = instance, .owner = self, .run = runTask, .abort = abortOwner, .free = freeOwner }, .resource = .{ .allocator = allocator, .ctx = ctx, .owner = self, .notify = InternalState.queueRead } };
    try Registry.set(instance, self);
    instance.getState(State).own._internal = self;
    return instance;
}
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |self| {
        state.own._internal = null;
        // Its own exit from here: the sweep is for the states no deinit
        // reaches.
        Registry.remove(instance);
        self.cancel();
        if (self.track) |track| self.kept.release(track, hooks.trackElementDestroyed);
        self.activity.detach();
        self.activity.maybeFree();
    }
    interfaces.HTMLElement.deinit(instance);
}
fn freeOwner(context: *anyopaque) void {
    const self: *InternalState = @ptrCast(@alignCast(context));
    self.resource.stop();
    const allocator = self.activity.allocator;
    if (self.url) |url| allocator.free(url);
    if (self.selected_url) |url| allocator.free(url);
    self.body.deinit(allocator);
    self.activity.microtasks.deinit(allocator);
    self.arena.destroy(InternalState, self);
}
/// The states of the tracks no deinit has reached yet, by element: the
/// orphans' are what is left at the Browser's end. The blocks are not the
/// registry's (`set`): `freeOwner` returns each.
const Registry = runtime.InstanceRegistry(.html_track_element, InternalState);

/// `dom.teardown_sweeps`: free the state of every track element of `scope`'s
/// Browser that no deinit reached - an orphan - at the Browser's end, as its
/// last task would have (`freeOwner`). The realm's end and the event loop's,
/// before this, dropped its tasks; one still holding
/// work is left to that work rather than freed under it. Its text track is
/// an object of its own, the collector's.
fn sweepRemaining(scope: *runtime.BrowserScope) void {
    var entries = Registry.iterator(scope) orelse return;
    while (entries.next()) |entry| {
        const self = entry.internal;
        self.activity.instance = null;
        self.activity.kept_alive = false;
        self.activity.maybeFree();
    }
    Registry.clear(scope);
}
fn abortOwner(context: *anyopaque) void {
    const self: *InternalState = @ptrCast(@alignCast(context));
    self.cancel();
}
pub fn call_constructor(instance: *runtime.Instance) !void {
    // The generated constructor made it (WebIDL 3.7.1 step 1.8): no steps.
    _ = instance;
}
pub fn get_track(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return ensureTrack(instance);
}
fn ensureTrack(instance: *runtime.Instance) !*runtime.Instance {
    const self = data(instance);
    if (self.track) |track| return track;
    // HTML: "each track element has a corresponding text track". Lazy
    // allocation is unobservable: mode starts disabled, readiness not loaded,
    // and attributes live on the element. Q22: every made child is handed out
    // immediately, including the addtrack/TrackEvent-first path, so no unseen
    // unwrapped child is left for a wrapper collector that never knew it.
    var label = (try interfaces.Element.call_getAttribute(instance, .initInterned("label"))) orelse runtime.DOMString.initEmpty();
    defer label.deinit(instance.ctx.allocator);
    var language = (try interfaces.Element.call_getAttribute(instance, .initInterned("srclang"))) orelse runtime.DOMString.initEmpty();
    defer language.deinit(instance.ctx.allocator);
    var id = (try interfaces.Element.call_getAttribute(instance, .initInterned("id"))) orelse runtime.DOMString.initEmpty();
    defer id.deinit(instance.ctx.allocator);
    const track = try hooks.createTrackElementTrack(instance.ctx, try kindOf(instance), label, language, id);
    self.track = track;
    self.kept.made(track);
    self.kept.handOut(instance, track, .{ .name = "track" });
    hooks.linkTrackElement(track, instance);
    return track;
}
pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
    const track = data(instance).track orelse return 0;
    return @backingInt(hooks.trackReadiness(track));
}
pub fn get_kind(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return .initInterned(@tagName(try kindOf(instance)));
}
pub fn set_kind(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, .initInterned("kind"), .{ .domstring = value });
}
fn kindOf(instance: *runtime.Instance) !hooks.Kind {
    var value = (try interfaces.Element.call_getAttribute(instance, .initInterned("kind"))) orelse return .subtitles;
    defer value.deinit(instance.ctx.allocator);
    inline for (comptime std.meta.fieldNames(hooks.Kind), @typeInfo(hooks.Kind).@"enum".field_values) |field_name, field_value| if (std.ascii.eqlIgnoreCase(value.asSlice(), field_name)) return @fromBackingInt(@intCast(field_value));
    return .metadata;
}
pub fn installHooks() void {
    hooks.installTrackElement(modeChanged);
    dom.attribute_change_steps.install("track", attributeChanged);
    dom.mutation.registerInsertionStepsCallback(inserted) catch @panic("track insertion hook allocation");
    dom.mutation.registerRemovingStepsCallback(removed) catch @panic("track removing hook allocation");
    dom.document_fetches.install(.{ .discard = cancelRealm, .prepare_abort = prepareDocumentAbort, .abort = abortDocument });
    dom.unloading_cleanup.install(cancelRealm);
    // The states no deinit reached - orphaned tracks' - at their Browser's
    // end.
    dom.teardown_sweeps.install(.element_types, &sweepRemaining);
}
/// The text track's mode changed: start the track processing model. (Its
/// media element hears of the change from the track itself, as for any
/// track in its list of text tracks: TextTrack.set_mode.)
fn modeChanged(instance: *runtime.Instance, _: hooks.Mode, _: hooks.Mode) void {
    data(instance).start() catch data(instance).cancel();
}
fn updateAttributes(instance: *runtime.Instance) !void {
    const track = data(instance).track orelse return;
    var label = (try interfaces.Element.call_getAttribute(instance, .initInterned("label"))) orelse runtime.DOMString.initEmpty();
    defer label.deinit(instance.ctx.allocator);
    var language = (try interfaces.Element.call_getAttribute(instance, .initInterned("srclang"))) orelse runtime.DOMString.initEmpty();
    defer language.deinit(instance.ctx.allocator);
    var id = (try interfaces.Element.call_getAttribute(instance, .initInterned("id"))) orelse runtime.DOMString.initEmpty();
    defer id.deinit(instance.ctx.allocator);
    try hooks.updateTrackAttributes(track, try kindOf(instance), label, language, id);
}
fn attributeChanged(instance: *runtime.Instance, name: []const u8, _: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    if (namespace != null) return;
    const self = data(instance);
    if (std.mem.eql(u8, name, "src")) {
        const url = if (value) |text| (if (text.len != 0) html.encoding_parse.encodingParseAndSerialize(instance, text) catch null else null) else null;
        const unchanged = std.mem.eql(u8, self.url orelse "", url orelse "");
        if (self.url) |old| self.activity.allocator.free(old);
        self.url = url;
        // All three browsers (Chrome, Firefox, Safari) keep existing cues when
        // src is assigned the same URL (whatwg/html#2916;
        // track-element-src-change.html). When the URL changes or is removed,
        // immediately empty the text track's list of cues (HTML 4.8.11.11.3;
        // Gecko AfterSetAttr).
        if (!unchanged) {
            if (self.track) |track| hooks.clearTrackCues(track);
        }
        self.start() catch self.cancel();
    } else if (std.mem.eql(u8, name, "kind") or std.mem.eql(u8, name, "label") or std.mem.eql(u8, name, "srclang") or std.mem.eql(u8, name, "id")) updateAttributes(instance) catch {};
}
fn inserted(node: *dom.NodeBase) void {
    const instance = dom.instance_bridge.getInstanceTyped(runtime.Instance, node) orelse return;
    if (!std.mem.eql(u8, instance.vtable.name, "HTMLTrackElement")) return;
    const self = data(instance);
    const old = if (self.parent) |link| (if (link.isLive()) link.instance else null) else null;
    const current = interfaces.Node.get_parentNode(instance) catch null;
    if (old != current) {
        self.parent = if (current) |parent| same_object.Link.to(parent) else null;
        hooks.trackElementParentChanged(instance, old, current);
    }
    data(instance).start() catch data(instance).cancel();
}
fn removed(node: *dom.NodeBase, _: ?*dom.NodeBase) void {
    const instance = dom.instance_bridge.getInstanceTyped(runtime.Instance, node) orelse return;
    if (std.mem.eql(u8, instance.vtable.name, "HTMLTrackElement")) {
        const self = data(instance);
        self.cancel();
        // DOM passes the removed subtree's old ancestor to every descendant.
        // HTML track membership follows changes to this track's direct parent.
        const old = if (self.parent) |link| (if (link.isLive()) link.instance else null) else null;
        const current = interfaces.Node.get_parentNode(instance) catch null;
        if (old != current) {
            self.parent = if (current) |parent| same_object.Link.to(parent) else null;
            hooks.trackElementParentChanged(instance, old, current);
        }
    }
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
        if (std.mem.eql(u8, instance.vtable.name, "HTMLTrackElement")) data(instance).cancel();
    }
}
fn prepareDocumentAbort(document: *runtime.Instance) bool {
    const registry = common.liveRegistry(document.ctx) orelse return false;
    var canceled = false;
    for (registry.entries.toSlice()) |entry| {
        const instance: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
        if (!std.mem.eql(u8, instance.vtable.name, "HTMLTrackElement")) continue;
        const self = data(instance);
        const link = self.fetch_document orelse continue;
        if (!self.activity.fetching or link.instance != document or !link.isLive()) continue;
        self.document_abort_pending = self.generation;
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
                if (!std.mem.eql(u8, instance.vtable.name, "HTMLTrackElement")) continue;
                const candidate = data(instance);
                const link = candidate.fetch_document orelse continue;
                if (candidate.document_abort_pending != null and link.instance == document and link.isLive()) break :blk candidate;
            }
            return;
        };
        const generation = self.document_abort_pending.?;
        self.document_abort_pending = null;
        if (generation != self.generation or !self.activity.fetching) continue;
        const instance = self.activity.instance orelse continue;
        engine.runInRealm(instance.ctx, documentAbortSteps, self) catch self.cancel();
    }
}
fn documentAbortSteps(context: ?*anyopaque) void {
    const self: *InternalState = @ptrCast(@alignCast(context.?));
    self.generation +%= 1;
    self.activity.discardTasks(false);
    self.start_queued = false;
    self.stopFetch();
    // Failed fetch processing is a new element task. The old resource's
    // queued reads keep their owners until run/drop but cannot dispatch.
    self.queue(.failure) catch self.cancel();
    self.activity.sync();
}
/// The task `awaitTop` queued: steps 6-10.
fn startSteps(self: *InternalState) void {
    self.start_queued = false;
    const instance = self.activity.instance orelse return;
    startFetch(instance) catch self.cancel();
}
fn startFetch(instance: *runtime.Instance) !void {
    const self = data(instance);
    // Synchronous section steps 6–8.
    hooks.setTrackReadiness(self.track.?, .loading);
    const selected = try self.activity.allocator.dupe(u8, self.url orelse "");
    if (self.selected_url) |old| self.activity.allocator.free(old);
    self.selected_url = selected;
    // An empty URL fails (step 8) - and so does one in a document with no
    // browsing context, unfetched (common.hasBrowsingContext).
    if (selected.len == 0 or !common.hasBrowsingContext(instance)) {
        try self.queue(.failure);
        return;
    }
    const parent = interfaces.Node.get_parentNode(instance) catch null;
    var cors = if (parent) |owner| (if (common.isMedia(owner)) try interfaces.HTMLMediaElement.get_crossOrigin(owner) else null) else null;
    defer if (cors) |*value| value.deinit(instance.ctx.allocator);
    const request = try common.requestFor(instance, selected, .track, html.script_request.corsSettingFromAttribute(if (cors) |value| value.asSlice() else null));
    self.fetch_document = if (common.documentOf(instance)) |document| same_object.Link.to(document) else null;
    self.activity.fetching = true;
    self.activity.sync();
    self.resource.start(request) catch {
        try self.queue(.failure);
    };
}
fn runTask(context: *anyopaque, task: *common.Task) void {
    const self: *InternalState = @ptrCast(@alignCast(context));
    if (task.generation != self.generation) return;
    switch (@as(Kind, @fromBackingInt(@intCast(task.kind)))) {
        .failure => self.failed(task),
        .start => startSteps(self),
        .read => {
            self.read_queued = false;
            const piece = self.resource.next() catch {
                self.queue(.failure) catch self.cancel();
                return;
            };
            if (piece) |value| switch (value) {
                .headers => |response| {
                    if (response.response_type == .@"error" or response.status < 200 or response.status >= 300) {
                        self.queue(.failure) catch self.cancel();
                    } else {
                        // Step 10: "determine the type of the resource". The
                        // one format is WebVTT, whose parser checks the file
                        // signature itself; the response's MIME type does not
                        // decide, as in Chrome and Firefox (fetch/metadata/
                        // track.https.sub.html's resource is an untyped
                        // "WEBVTT": all three browsers fire load, wpt.fyi runs
                        // 4786307730243584 / 4877168468033536 / 6479119966273536).
                        // Read on: a buffered body arrives with no further
                        // notification.
                        self.body.clearRetainingCapacity();
                        InternalState.queueRead(self);
                    }
                },
                .failed => self.queue(.failure) catch self.cancel(),
                .bytes => |bytes| {
                    self.body.appendSlice(self.activity.allocator, bytes) catch return self.failed(task);
                    InternalState.queueRead(self);
                },
                .eof => self.processResource(task),
            };
        },
    }
}
