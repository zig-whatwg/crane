//! CSS Typed OM 1 4.4: CSSMatrixComponent - matrix() and matrix3d() - whose
//! matrix slot is a DOMMatrix.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const dom = @import("dom");
const typed_om = dom.style.typed_om;

pub const State = interfaces.CSSMatrixComponent.State;
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

/// CSSMatrixComponent(matrix, options): 1. a new CSSMatrixComponent whose
/// matrix slot is `matrix`; 2. is2D from options' is2D when passed, 3. else
/// matrix's is2D. The slot is the attribute's type, a DOMMatrix: a
/// DOMMatrixReadOnly argument is copied into one (Blink
/// CSSMatrixComponent::Create makes a DOMMatrix of it), a DOMMatrix is kept.
pub fn call_constructor(ctx: runtime.Context, matrix: *runtime.Instance, options: webidl.Opt(dictionaries.CSSMatrixComponentOptions)) !*runtime.Instance {
    const given: ?bool = if (options.was_passed) options.value.is2D else null;
    const is_2d = given orelse try interfaces.DOMMatrixReadOnly.get_is2D(matrix);
    var holds = typed_om.SlotHolds.init(ctx);
    defer holds.deinit();
    if (matrix.stateAs(interfaces.DOMMatrix.State) != null) {
        try holds.keep(matrix, false);
    } else try holds.keep(try typed_om.copyMatrix(ctx, matrix), true);
    return interfaces.CSSMatrixComponent.initWith(ctx.allocator, ctx, .{ .transform_is_2d = is_2d, .transform_slots = holds.values() });
}

pub fn get_matrix(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return internal.get(0);
}

pub fn set_matrix(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    try internal.set(instance, 0, value);
}
