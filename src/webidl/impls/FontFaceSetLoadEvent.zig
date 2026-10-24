//! CSS Font Loading 3 §3: a font-load event owns one frozen face array.
//! The array is a traced member, so an event/face cycle is collectible.
//! Blink's FontFaceSetLoadEvent::Trace traces fontfaces_ from the event;
//! Crane uses the engine protocol's owner-traced value for that edge.
//!
//! Spec: https://drafts.csswg.org/css-font-loading/#fontfacesetloadevent

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const event_construction = @import("dom").event_construction;
const FontFaceSetLoadEvent = interfaces.FontFaceSetLoadEvent;

pub const State = FontFaceSetLoadEvent.State;

pub const ImplError = error{
    InvalidStateError,
};

/// No native member array or root accompanies the traced array.
pub const InternalState = struct {};
const faces_slot: engine.TracedSlot = .{ .name = "fontfaces" };

/// The generated chain constructs the Event parent before this own part.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = args;
    instance.getState(StateType).own._internal = null;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    // An event freed before wrapping must end its temporary strong edge.
    // A wrapped event's edge dies with the wrapper; this is then a no-op.
    engine.forgetTracedChild(instance, faces_slot);
}

/// DOM §2.5 inner event creation steps, followed by the dictionary's
/// fontfaces member. WebIDL's FrozenArray conversion copies the sequence;
/// retain neither its caller-owned storage nor a parallel native root.
pub fn call_constructor(ctx: runtime.Context, @"type": typedefs.CSSOMString, eventInitDict: webidl.Opt(dictionaries.FontFaceSetLoadEventInit)) !*runtime.Instance {
    const instance = try FontFaceSetLoadEvent.init(ctx.allocator, ctx);
    errdefer runtime.Instance.deinit(instance);
    const dict: dictionaries.FontFaceSetLoadEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{} };
    try event_construction.innerEventCreationSteps(instance, @"type", event_construction.eventInitFrom(dict.base));
    const members = dict.fontfaces orelse &.{};
    const values = try ctx.allocator.alloc(runtime.JSValue, members.len);
    defer ctx.allocator.free(values);
    for (members, values) |member, *value| value.* = .{ .instance = member };
    const array = try engine.createFrozenArray(ctx, values);
    defer array.release();
    engine.traceValue(instance, array.borrow(), faces_slot);
    return instance;
}

/// SameObject: each binding read owns a hold of the same traced array.
pub fn get_fontfaces(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return (engine.tracedValue(instance, faces_slot) orelse return error.InvalidStateError).take();
}
