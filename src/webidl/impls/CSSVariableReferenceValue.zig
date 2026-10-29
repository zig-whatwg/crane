//! CSS Typed OM 1 §4.1: a custom property name and an optional fallback.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const css = @import("css");
const dom = @import("dom");

pub const State = interfaces.CSSVariableReferenceValue.State;
pub const ImplError = error{TypeError};
pub const construction_args = .{ "variable_name", "variable_fallback" };
pub const InternalState = struct {
    name: []u8,
    fallback: dom.style.rules.ObjectLink = .{},
};
const fallback_slot: engine.TracedSlot = .{ .name = "CSSVariableReferenceValue:fallback" };

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    const name = if (@hasField(@TypeOf(args), "variable_name")) args.variable_name else "--";
    const fallback: ?*runtime.Instance = if (@hasField(@TypeOf(args), "variable_fallback")) args.variable_fallback else null;
    if (!css.typed_om.unparsed.isCustomPropertyName(name)) return error.TypeError;
    if (fallback) |child| if (child.stateAs(interfaces.CSSUnparsedValue.State) == null) return error.TypeError;
    const copy = try allocator.dupe(u8, name);
    errdefer allocator.free(copy);
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .name = copy };
    instance.getState(State).own._internal = internal;
    if (fallback) |child| {
        internal.fallback.set(child);
        dom.style.objects.keepFrom(instance, child, fallback_slot);
    }
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    engine.forgetTracedChild(instance, fallback_slot);
    instance.ctx.allocator.free(internal.name);
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

pub fn call_constructor(ctx: runtime.Context, variable: runtime.USVString, fallback: webidl.Opt(?*runtime.Instance)) !*runtime.Instance {
    // Constructor steps 1–2. The fallback is nullable but is never copied.
    return interfaces.CSSVariableReferenceValue.initWith(ctx.allocator, ctx, .{
        .variable_name = variable,
        .variable_fallback = if (fallback.wasPassed()) fallback.getValue() else @as(?*runtime.Instance, null),
    });
}

pub fn get_variable(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return instance.ctx.allocator.dupe(u8, internal.name);
}

pub fn get_fallback(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return internal.fallback.get();
}

pub fn set_variable(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // Setter steps 1–2: validate and copy before replacing the old value.
    if (!css.typed_om.unparsed.isCustomPropertyName(value)) return error.TypeError;
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const copy = try instance.ctx.allocator.dupe(u8, value);
    instance.ctx.allocator.free(internal.name);
    internal.name = copy;
}
