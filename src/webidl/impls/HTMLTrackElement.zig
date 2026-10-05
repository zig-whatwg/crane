//! HTML 4.8.11.11.3: out-of-band text track processing.
//! Scope (media Q10): no text track formats are supported yet. WebVTT parser,
//! cue ownership and VTTCue/TextTrackCue are the queued follow-up. A real fetch
//! therefore ends in the specification's unsupported-format error path.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");
const common = html.media_runtime;
const hooks = dom.media_elements;
const same_object = @import("same_object.zig");
pub const State = interfaces.HTMLTrackElement.State;
const Kind = enum(u16) { read, failure };
pub const InternalState = struct {
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
        self.unregister();
        self.activity.sync();
    }
    fn queue(self: *InternalState, kind: Kind) !void {
        _ = try self.activity.queue(@intFromEnum(kind), self.generation, null, "error");
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
            try self.activity.stable(self.generation, stable);
        } else if (!std.mem.eql(u8, self.url orelse "", self.selected_url orelse "")) {
            // Step 10 aborts a changed URL and discards all its pending tasks.
            // Step 12 then resumes from top only while enabled.
            self.generation +%= 1;
            self.activity.discardTasks(false);
            self.stopFetch();
            if (self.waiting) {
                self.waiting = false;
                if (common.liveRegistry(instance.ctx)) |registry| try registry.add(instance, instance.ctx);
                try self.activity.stable(self.generation, stable);
            } else try self.queue(.failure);
        }
    }
    fn queueRead(context: *anyopaque) void {
        const self: *InternalState = @ptrCast(@alignCast(context));
        if (self.activity.instance == null or self.read_queued) return;
        self.read_queued = true;
        self.queue(.read) catch self.cancel();
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
fn data(instance: *runtime.Instance) *InternalState {
    return instance.getState(State).own._internal.?;
}
pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.HTMLElement.initWithState(allocator, StateType, vtable, ctx);
    instance.getState(State).own._internal = null;
    errdefer instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
    const self = try allocator.create(InternalState);
    self.* = .{ .activity = .{ .allocator = allocator, .instance = instance, .owner = self, .run = runTask, .abort = abortOwner, .free = freeOwner }, .resource = .{ .allocator = allocator, .ctx = ctx, .owner = self, .notify = InternalState.queueRead } };
    instance.getState(State).own._internal = self;
    return instance;
}
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |self| {
        state.own._internal = null;
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
    self.activity.microtasks.deinit(allocator);
    allocator.destroy(self);
}
fn abortOwner(context: *anyopaque) void {
    const self: *InternalState = @ptrCast(@alignCast(context));
    self.cancel();
}
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    return init(ctx.allocator, State, &interfaces.HTMLTrackElement.vtable, ctx);
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
    return @intFromEnum(hooks.trackReadiness(track));
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
    inline for (std.meta.fields(hooks.Kind)) |field| if (std.ascii.eqlIgnoreCase(value.asSlice(), field.name)) return @enumFromInt(field.value);
    return .metadata;
}
pub fn installHooks() void {
    hooks.installTrackElement(modeChanged);
    dom.attribute_change_steps.install("track", attributeChanged);
    dom.mutation.registerInsertionStepsCallback(inserted) catch @panic("track insertion hook allocation");
    dom.mutation.registerRemovingStepsCallback(removed) catch @panic("track removing hook allocation");
    dom.document_fetches.install(cancelRealm);
    dom.unloading_cleanup.install(cancelRealm);
}
fn modeChanged(instance: *runtime.Instance, _: hooks.Mode, _: hooks.Mode) void {
    if (interfaces.Node.get_parentNode(instance) catch null) |parent| if (common.isMedia(parent)) hooks.textTrackModeChanged(parent);
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
        if (self.url) |old| self.activity.allocator.free(old);
        self.url = url;
        // No format is supported, hence the cue lists are already empty (Q10).
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
fn removed(node: *dom.NodeBase, old_parent: ?*dom.NodeBase) void {
    const instance = dom.instance_bridge.getInstanceTyped(runtime.Instance, node) orelse return;
    if (std.mem.eql(u8, instance.vtable.name, "HTMLTrackElement")) {
        data(instance).cancel();
        const old = if (old_parent) |parent| dom.instance_bridge.getInstanceTyped(runtime.Instance, parent) else null;
        const current = interfaces.Node.get_parentNode(instance) catch null;
        // Removing steps also visit descendants whose own parent did not move.
        if (old_parent != null and old != current) {
            data(instance).parent = if (current) |parent| same_object.Link.to(parent) else null;
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
fn stable(context: ?*anyopaque) void {
    const instance: *runtime.Instance = @ptrCast(@alignCast(context.?));
    const self = instance.getState(State).own._internal orelse return;
    const generation = self.activity.beginStable() orelse return;
    defer self.activity.endStable();
    if (generation != self.generation or !instance.ctx.hasEngine()) return;
    engine.runInRealm(instance.ctx, stableSteps, instance) catch self.cancel();
}
fn stableSteps(context: ?*anyopaque) void {
    const instance: *runtime.Instance = @ptrCast(@alignCast(context.?));
    startFetch(instance) catch data(instance).cancel();
}
fn startFetch(instance: *runtime.Instance) !void {
    const self = data(instance);
    // Synchronous section steps 6–8.
    hooks.setTrackReadiness(self.track.?, .loading);
    const selected = try self.activity.allocator.dupe(u8, self.url orelse "");
    if (self.selected_url) |old| self.activity.allocator.free(old);
    self.selected_url = selected;
    if (selected.len == 0) {
        try self.queue(.failure);
        return;
    }
    const parent = interfaces.Node.get_parentNode(instance) catch null;
    var cors = if (parent) |owner| (if (common.isMedia(owner)) try interfaces.HTMLMediaElement.get_crossOrigin(owner) else null) else null;
    defer if (cors) |*value| value.deinit(instance.ctx.allocator);
    const request = try common.requestFor(instance, selected, .track, html.script_request.corsSettingFromAttribute(if (cors) |value| value.asSlice() else null));
    self.activity.fetching = true;
    self.activity.sync();
    self.resource.start(request) catch {
        try self.queue(.failure);
    };
}
fn runTask(context: *anyopaque, task: *common.Task) void {
    const self: *InternalState = @ptrCast(@alignCast(context));
    if (task.generation != self.generation) return;
    switch (@as(Kind, @enumFromInt(task.kind))) {
        .failure => self.failed(task),
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
                        // Step 10: unsupported format found in this networking task.
                        self.failed(task);
                    }
                },
                .failed => self.queue(.failure) catch self.cancel(),
                .bytes, .eof => self.failed(task),
            };
        },
    }
}
