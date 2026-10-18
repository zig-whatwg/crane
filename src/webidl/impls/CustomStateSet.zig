//! HTML 4.13.7.5 CustomStateSet: a custom element's states set.
//!
//! `interface CustomStateSet { setlike<DOMString>; };` - the set entries are
//! this impl's (a webidl.setlike.Strings); their setlike members, size, has,
//! add, delete, clear, forEach and the iterators, are the binding's (WebIDL
//! 3.7.12), which reaches them through the generated `setlikeEntries`. The
//! `:state()` pseudo-class reads them natively (the custom states hook).
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const ce = @import("dom").custom_elements;

pub const State = interfaces.CustomStateSet.State;
pub const InternalState = struct {
    /// The states set's values (HTML: "a CustomStateSet, initially empty").
    values: webidl.setlike.Strings,
    target_traced: bool = false,
};

fn internalOf(instance: *runtime.Instance) !*InternalState {
    return instance.getState(State).own._internal orelse error.InvalidStateError;
}

pub fn installHooks() void {
    ce.installCustomStates(.{ .set_target = &setTarget, .has = &hasState });
}

fn setTarget(instance: *runtime.Instance, target: *runtime.Instance) !void {
    const internal = try internalOf(instance);
    // Blink's CustomStateSet traces its element. This edge keeps the target
    // reachable only while script can reach the set, without a persistent root.
    if (instance.ctx.hasEngine()) {
        engine.traceChild(instance, target, .{ .name = "targetElement" });
        internal.target_traced = true;
    }
}

/// `:state(value)` matches when the states set contains `value`.
fn hasState(instance: *runtime.Instance, value: []const u8) bool {
    return (internalOf(instance) catch return false).values.contains(value);
}

pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .values = .init(allocator) };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    if (internal.target_traced) engine.forgetTracedChild(instance, .{ .name = "targetElement" });
    const allocator = internal.values.allocator;
    internal.values.deinit();
    allocator.destroy(internal);
    state.own._internal = null;
}

/// The states set's set entries (WebIDL 2.5.12), for the binding's setlike
/// members; null once the instance's state is gone.
pub fn setlikeEntries(instance: *runtime.Instance) ?*webidl.setlike.Strings {
    const internal = internalOf(instance) catch return null;
    return &internal.values;
}
