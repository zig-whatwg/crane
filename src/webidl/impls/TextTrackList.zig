//! HTML 4.8.11.11: an ordered EventTarget-backed list, with one edge per track.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");
pub const State = interfaces.TextTrackList.State;
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    tracks: std.ArrayList(*runtime.Instance) = .empty,
};
fn data(instance: *runtime.Instance) *InternalState {
    return instance.getState(State).own._internal.?;
}
fn slot(buffer: []u8, track: *runtime.Instance) engine.TracedSlot {
    return .{ .name = std.fmt.bufPrint(buffer, "track:{x}", .{@intFromPtr(track)}) catch unreachable };
}
pub fn installHooks() void {
    dom.media_elements.installTextTrackList(.{ .create = create, .append = append, .remove = remove });
}
pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.EventTarget.initWithState(allocator, StateType, vtable, ctx);
    instance.getState(State).own._internal = null;
    errdefer instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(State).own._internal = internal;
    return instance;
}
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        state.own._internal = null;
        // Only names are used here: a collector may have freed a track first.
        for (internal.tracks.items) |track| {
            var buffer: [32]u8 = undefined;
            engine.forgetTracedChild(instance, slot(&buffer, track));
        }
        internal.tracks.deinit(internal.allocator);
        internal.allocator.destroy(internal);
    }
    interfaces.EventTarget.deinit(instance);
}
fn create(ctx: runtime.Context) !*runtime.Instance {
    return interfaces.TextTrackList.init(ctx.allocator, ctx);
}
fn append(instance: *runtime.Instance, track: *runtime.Instance) !void {
    const internal = data(instance);
    for (internal.tracks.items) |existing| if (existing == track) return;
    try internal.tracks.append(internal.allocator, track);
    var buffer: [32]u8 = undefined;
    engine.traceChild(instance, track, slot(&buffer, track));
}
fn remove(instance: *runtime.Instance, track: *runtime.Instance) void {
    const internal = data(instance);
    for (internal.tracks.items, 0..) |existing, index| if (existing == track) {
        _ = internal.tracks.orderedRemove(index);
        var buffer: [32]u8 = undefined;
        engine.forgetTracedChild(instance, slot(&buffer, track));
        return;
    };
}
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    return @intCast(data(instance).tracks.items.len);
}
pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
    const tracks = data(instance).tracks.items;
    if (index >= tracks.len) return error.IndexSizeError;
    return tracks[index];
}
pub fn call_getTrackById(instance: *runtime.Instance, id: runtime.DOMString) anyerror!?*runtime.Instance {
    for (data(instance).tracks.items) |track| {
        var track_id = try interfaces.TextTrack.get_id(track);
        defer track_id.deinit(instance.ctx.allocator);
        if (std.mem.eql(u8, track_id.asSlice(), id.asSlice())) return track;
    }
    return null;
}
