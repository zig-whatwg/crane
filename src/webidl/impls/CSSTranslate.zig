//! CSS Typed OM 1 4.4: CSSTranslate - translate(), translateX/Y/Z() and
//! translate3d() - with x, y and z slots.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const dom = @import("dom");
const typed_om = dom.style.typed_om;

pub const State = interfaces.CSSTranslate.State;
pub const ImplError = error{TypeError};
pub const construction_args = .{"transform_slots"};
pub const InternalState = typed_om.TransformLinks;

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    errdefer runtime.arenaOf(instance).destroy(InternalState, internal);
    internal.* = try typed_om.TransformLinks.init(instance, args.transform_slots);
    instance.getState(State).own._internal = internal;
    internal.trace(instance);
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    internal.deinit(instance);
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

/// CSSTranslate(x, y, z):
/// 1. If x or y don't match <length-percentage>, throw a TypeError.
/// 2. If z was passed, but doesn't match <length>, throw a TypeError.
/// 3-5. x and y as given; z as given and is2D false, or a new unit value of
///    (0, "px") and is2D true.
pub fn call_constructor(ctx: runtime.Context, x: *runtime.Instance, y: *runtime.Instance, z: webidl.Opt(*runtime.Instance)) !*runtime.Instance {
    if (!try typed_om.numericMatches(x, .length_percentage) or !try typed_om.numericMatches(y, .length_percentage)) return error.TypeError;
    if (z.was_passed and !try typed_om.numericMatches(z.value, .length)) return error.TypeError;
    var holds = typed_om.SlotHolds.init(ctx);
    defer holds.deinit();
    try holds.keep(x, false);
    try holds.keep(y, false);
    if (z.was_passed) try holds.keep(z.value, false) else try holds.keep(try typed_om.unitSlot(ctx, 0, "px"), true);
    return interfaces.CSSTranslate.initWith(ctx.allocator, ctx, .{ .transform_is_2d = !z.was_passed, .transform_slots = holds.values() });
}

fn slot(instance: *runtime.Instance, index: usize) !*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return internal.get(index);
}

/// The setters check what the constructor does (Blink CSSTranslate::setX/
/// setY/setZ throw a TypeError for a value of another type); the spec names
/// no setter steps.
fn put(instance: *runtime.Instance, index: usize, value: *runtime.Instance, production: dom.style.typed_om.Production) !void {
    if (!try typed_om.numericMatches(value, production)) return error.TypeError;
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    try internal.set(instance, index, value);
}

pub fn get_x(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return slot(instance, 0);
}
pub fn get_y(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return slot(instance, 1);
}
pub fn get_z(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return slot(instance, 2);
}
pub fn set_x(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
    return put(instance, 0, value, .length_percentage);
}
pub fn set_y(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
    return put(instance, 1, value, .length_percentage);
}
pub fn set_z(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
    return put(instance, 2, value, .length);
}
