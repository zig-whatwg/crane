//! HTML 4.8.11.11: an out-of-band text track owns its attributes and readiness.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const enums = @import("enums");
const typedefs = @import("typedefs");
const dom = @import("dom");
const hooks = dom.media_elements;
const same_object = @import("same_object.zig");
pub const State = interfaces.TextTrack.State;
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    kind: hooks.Kind = .subtitles,
    label: runtime.DOMString = .initEmpty(),
    language: runtime.DOMString = .initEmpty(),
    id: runtime.DOMString = .initEmpty(),
    mode: hooks.Mode = .disabled,
    readiness: hooks.Readiness = .not_loaded,
    element: ?same_object.Link = null,
    cues: ?*runtime.Instance = null,
    cues_keep: same_object.KeptChild = .{},
    active: ?*runtime.Instance = null,
    active_keep: same_object.KeptChild = .{},
};
pub fn installHooks() void {
    hooks.installTextTrack(.{ .create = create, .update = update, .set_readiness = setReadiness, .readiness = readiness, .link_element = linkElement, .element_destroyed = elementDestroyed });
}
pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.EventTarget.initWithState(allocator, StateType, vtable, ctx);
    instance.getState(State).own._internal = null;
    errdefer instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
    const data = try allocator.create(InternalState);
    data.* = .{ .allocator = allocator };
    instance.getState(State).own._internal = data;
    return instance;
}
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |data| {
        state.own._internal = null;
        // A wrapper-held child is freed by the collector, never eagerly here.
        if (data.cues) |child| data.cues_keep.release(child, severCues);
        if (data.active) |child| data.active_keep.release(child, severCues);
        data.label.deinit(data.allocator);
        data.language.deinit(data.allocator);
        data.id.deinit(data.allocator);
        data.allocator.destroy(data);
    }
    interfaces.EventTarget.deinit(instance);
}
fn severCues(_: *runtime.Instance) void {}
fn internal(instance: *runtime.Instance) *InternalState {
    return instance.getState(State).own._internal.?;
}
fn create(ctx: runtime.Context, kind: hooks.Kind, label: runtime.DOMString, language: runtime.DOMString, id: runtime.DOMString) !*runtime.Instance {
    // Association steps: independent owned values, disabled, not loaded.
    const track = try interfaces.TextTrack.init(ctx.allocator, ctx);
    errdefer track.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(track));
    try update(track, kind, label, language, id);
    return track;
}
fn update(track: *runtime.Instance, kind: hooks.Kind, label: runtime.DOMString, language: runtime.DOMString, id: runtime.DOMString) !void {
    const data = internal(track);
    // Commit all attributes together; OOM cannot leave borrowed or mixed values.
    var new_label = try label.clone(data.allocator);
    errdefer new_label.deinit(data.allocator);
    var new_language = try language.clone(data.allocator);
    errdefer new_language.deinit(data.allocator);
    const new_id = try id.clone(data.allocator);
    data.label.deinit(data.allocator);
    data.language.deinit(data.allocator);
    data.id.deinit(data.allocator);
    data.kind = kind;
    data.label = new_label;
    data.language = new_language;
    data.id = new_id;
}
fn setReadiness(track: *runtime.Instance, value: hooks.Readiness) void {
    internal(track).readiness = value;
}
fn readiness(track: *runtime.Instance) hooks.Readiness {
    return internal(track).readiness;
}
fn linkElement(track: *runtime.Instance, element: *runtime.Instance) void {
    internal(track).element = same_object.Link.to(element);
    engine.traceChild(track, element, .{ .name = "trackElement" });
}
fn elementDestroyed(track: *runtime.Instance) void {
    // GC-safe sever: no engine operation, exactly the shadow-host precedent.
    if (track.getState(State).own._internal) |data| data.element = null;
}
pub fn get_kind(instance: *runtime.Instance) anyerror!enums.TextTrackKind {
    return @enumFromInt(@intFromEnum(internal(instance).kind));
}
pub fn get_label(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return internal(instance).label.clone(instance.ctx.allocator);
}
pub fn get_language(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return internal(instance).language.clone(instance.ctx.allocator);
}
pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return internal(instance).id.clone(instance.ctx.allocator);
}
pub fn get_inBandMetadataTrackDispatchType(_: *runtime.Instance) anyerror!runtime.DOMString {
    return .initEmpty();
}
pub fn get_mode(instance: *runtime.Instance) anyerror!enums.TextTrackMode {
    return @enumFromInt(@intFromEnum(internal(instance).mode));
}
pub fn set_mode(instance: *runtime.Instance, value: enums.TextTrackMode) anyerror!void {
    const data = internal(instance);
    const mode: hooks.Mode = @enumFromInt(@intFromEnum(value));
    const old = data.mode;
    if (old == mode) return;
    data.mode = mode;
    // Start the track processing model on a mode change. A severed or reused
    // slab slot is never read, even during forced native teardown.
    if (data.element) |link| if (link.isLive()) hooks.trackModeChanged(link.instance, old, mode);
}
pub fn get_cues(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const data = internal(instance);
    if (data.mode == .disabled) return null;
    if (data.cues == null) {
        data.cues = try interfaces.TextTrackCueList.init(data.allocator, instance.ctx);
        data.cues_keep.made(data.cues.?);
    }
    data.cues_keep.handOut(instance, data.cues.?, .{ .name = "cues" });
    return data.cues;
}
pub fn get_activeCues(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const data = internal(instance);
    if (data.mode == .disabled) return null;
    if (data.active == null) {
        data.active = try interfaces.TextTrackCueList.init(data.allocator, instance.ctx);
        data.active_keep.made(data.active.?);
    }
    data.active_keep.handOut(instance, data.active.?, .{ .name = "activeCues" });
    return data.active;
}
pub fn get_sourceBuffer(_: *runtime.Instance) anyerror!?*runtime.Instance {
    return null;
}
pub fn get_oncuechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "cuechange");
}
pub fn set_oncuechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "cuechange", value);
}
pub fn call_addCue(_: *runtime.Instance, _: *runtime.Instance) anyerror!void {
    // Cue ownership and WebVTT parsing are the separately queued follow-up (Q10).
    return error.NotImplemented;
}
pub fn call_removeCue(_: *runtime.Instance, _: *runtime.Instance) anyerror!void {
    return error.NotFoundError;
}
