//! CSS Typed OM 1 4.4: CSSPerspective - perspective() - whose length slot
//! is a <length> CSSNumericValue or the keyword none (a CSSKeywordValue).
//! Always 3D: its is2D setter does nothing (CSSTransformComponent).
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");
const typed_om = dom.style.typed_om;

pub const State = interfaces.CSSPerspective.State;
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

/// CSSPerspective(length): 1. a CSSNumericValue must match <length>, else
/// a TypeError; 2. otherwise rectify a keywordish value from length, which
/// must be an ASCII case-insensitive match for none, else a TypeError;
/// 3. return a new CSSPerspective with it and is2D false. OWNED by the
/// caller when made here (the keyword of a string).
fn rectified(ctx: runtime.Context, length: typedefs.CSSPerspectiveValue) !struct { value: *runtime.Instance, made: bool } {
    switch (length) {
        .cssnumeric_value => |value| {
            if (!try typed_om.numericMatches(value, .length)) return error.TypeError;
            return .{ .value = value, .made = false };
        },
        .csskeywordish => |keywordish| {
            const keyword, const made = switch (keywordish) {
                .csskeyword_value => |value| .{ value, false },
                // "Rectify a keywordish value": a string is a new
                // CSSKeywordValue of it.
                .domstring => |text| .{ try interfaces.CSSKeywordValue.call_constructor(ctx, text.asSlice()), true },
            };
            const generation = runtime.SlabAllocator.generationOf(keyword);
            errdefer if (made) runtime.Instance.releaseIfUnwrapped(keyword, generation);
            const name = try interfaces.CSSKeywordValue.get_value(keyword);
            defer keyword.ctx.allocator.free(name);
            if (!std.ascii.eqlIgnoreCase(name, "none")) return error.TypeError;
            return .{ .value = keyword, .made = made };
        },
    }
}

pub fn call_constructor(ctx: runtime.Context, length: typedefs.CSSPerspectiveValue) !*runtime.Instance {
    var holds = typed_om.SlotHolds.init(ctx);
    defer holds.deinit();
    const slot_value = try rectified(ctx, length);
    try holds.keep(slot_value.value, slot_value.made);
    return interfaces.CSSPerspective.initWith(ctx.allocator, ctx, .{ .transform_is_2d = false, .transform_slots = holds.values() });
}

pub fn get_length(instance: *runtime.Instance) anyerror!typedefs.CSSPerspectiveValue {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const value = try internal.get(0);
    if (value.stateAs(interfaces.CSSKeywordValue.State) != null) return .{ .csskeywordish = .{ .csskeyword_value = value } };
    return .{ .cssnumeric_value = value };
}

/// The setter checks as the constructor does (Blink CSSPerspective::
/// setLength throws a TypeError for a value it would not take).
pub fn set_length(instance: *runtime.Instance, value: typedefs.CSSPerspectiveValue) anyerror!void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    var holds = typed_om.SlotHolds.init(instance.ctx);
    defer holds.deinit();
    const slot_value = try rectified(instance.ctx, value);
    try holds.keep(slot_value.value, slot_value.made);
    try internal.set(instance, 0, slot_value.value);
}
