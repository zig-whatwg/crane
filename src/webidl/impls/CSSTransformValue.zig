//! CSS Typed OM 1 4.4: CSSTransformValue, a <transform-list>: a list of
//! CSSTransformComponents (its values to iterate over), with indexed
//! access, is2D and toMatrix().
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const typed_om = dom.style.typed_om;

pub const State = interfaces.CSSTransformValue.State;
pub const ImplError = error{ TypeError, RangeError };
pub const construction_args = .{"transform_components"};
pub const InternalState = typed_om.TransformLinks;

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    const components: []const *runtime.Instance = if (@hasField(@TypeOf(args), "transform_components")) args.transform_components else &.{};
    const internal = try runtime.arenaOf(instance).create(InternalState);
    errdefer runtime.arenaOf(instance).destroy(InternalState, internal);
    internal.* = try typed_om.TransformLinks.init(instance, components);
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

/// CSSTransformValue(transforms): the sequence<CSSTransformComponent>
/// conversion (each item a CSSTransformComponent, else a TypeError), then
/// 1. if transforms is empty, throw a TypeError; 2. a new CSSTransformValue
/// whose values to iterate over are transforms.
pub fn call_constructor(ctx: runtime.Context, transforms: runtime.JSValue) !*runtime.Instance {
    const Collect = struct {
        holds: typed_om.SlotHolds,

        fn item(data: ?*anyopaque, value: runtime.JSValue) engine.Error!void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            const component = engine.convertToPlatformObject(self.holds.held.ctx, value) orelse return error.TypeError;
            if (component.stateAs(interfaces.CSSTransformComponent.State) == null) return error.TypeError;
            try self.holds.keep(component, false);
        }
    };
    var collect: Collect = .{ .holds = typed_om.SlotHolds.init(ctx) };
    defer collect.holds.deinit();
    if (!try engine.iterate(ctx, transforms, Collect.item, &collect)) return error.TypeError;
    if (collect.holds.values().len == 0) return error.TypeError;
    return interfaces.CSSTransformValue.initWith(ctx.allocator, ctx, .{ .transform_components = collect.holds.values() });
}

pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return @intCast(internal.len());
}

/// is2D: true when every component's is2D is.
pub fn get_is2D(instance: *runtime.Instance) anyerror!bool {
    return typed_om.transformValueIs2d(instance);
}

/// toMatrix(): the identity (2D) multiplied by each component's matrix.
pub fn call_toMatrix(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return typed_om.transformValueToMatrix(instance);
}

/// "Determine the value of an indexed property": [[values]][n].
pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return internal.get(index);
}

/// "Set the value of an existing indexed property": [[values]][n] = new
/// value; "of a new indexed property": append it when n is the size, else
/// throw a RangeError.
pub fn call_setter(instance: *runtime.Instance, index: u32, value: *runtime.Instance) anyerror!void {
    if (value.stateAs(interfaces.CSSTransformComponent.State) == null) return error.TypeError;
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    try internal.set(instance, index, value);
}
