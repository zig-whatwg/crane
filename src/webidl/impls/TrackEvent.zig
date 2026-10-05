//! HTML TrackEvent: Event construction and a traced nullable track attribute.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const construction = @import("dom").event_construction;
const same_object = @import("same_object.zig");
pub const State = interfaces.TrackEvent.State;
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    track: ?*runtime.Instance = null,
    edge: same_object.Traced = .{ .slot = .{ .name = "track" } },
};
pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.Event.initWithState(allocator, StateType, vtable, ctx);
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
        data.edge.release(instance);
        data.allocator.destroy(data);
    }
    interfaces.Event.deinit(instance);
}
pub fn call_constructor(ctx: runtime.Context, event_type: runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.TrackEventInit)) !*runtime.Instance {
    const instance = try interfaces.TrackEvent.init(ctx.allocator, ctx);
    errdefer instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
    const dictionary = if (eventInitDict.wasPassed()) eventInitDict.value else dictionaries.TrackEventInit{ .base = .{} };
    // DOM inner event creation steps, including inherited EventInit flags.
    try construction.innerEventCreationSteps(instance, event_type, construction.eventInitFrom(dictionary.base));
    if (dictionary.track) |value| {
        const track = switch (value) {
            .instance => |object| object,
            .null, .undefined => return instance,
            else => engine.convertToPlatformObject(ctx, value) orelse return error.TypeError,
        };
        const name = track.vtable.name;
        if (!std.mem.eql(u8, name, "TextTrack") and !std.mem.eql(u8, name, "AudioTrack") and !std.mem.eql(u8, name, "VideoTrack")) return error.TypeError;
        const data = instance.getState(State).own._internal.?;
        data.track = track;
        data.edge.hold(instance, track);
    }
    return instance;
}
pub fn get_track(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    const data = instance.getState(State).own._internal.?;
    return if (data.track) |track| .{ .instance = track } else null;
}
