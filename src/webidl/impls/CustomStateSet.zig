//! HTML 4.13.7.5 / WebIDL 3.7.12 CustomStateSet query and mutation steps.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const ce = @import("dom").custom_elements;
const States = @import("html").custom_elements.States;

pub const State = interfaces.CustomStateSet.State;
pub const InternalState = struct {
    values: States,
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

fn hasState(instance: *runtime.Instance, value: []const u8) bool {
    return (internalOf(instance) catch return false).values.has(value);
}

pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .values = States.init(allocator) };
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

pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
    return @intCast((try internalOf(instance)).values.size);
}

pub fn call_has(instance: *runtime.Instance, value: runtime.DOMString) anyerror!bool {
    const internal = try internalOf(instance);
    return internal.values.has(value.asSlice());
}

pub fn call_add(instance: *runtime.Instance, value: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = try internalOf(instance);
    // WebIDL add steps 6–7: append once, then return the set itself.
    try internal.values.add(value.asSlice());
    return instance;
}

pub fn call_delete(instance: *runtime.Instance, value: runtime.DOMString) anyerror!bool {
    const internal = try internalOf(instance);
    return internal.values.remove(value.asSlice());
}

pub fn call_clear(instance: *runtime.Instance) anyerror!void {
    (try internalOf(instance)).values.clear();
}

pub fn call_forEach(instance: *runtime.Instance, callback: runtime.JSValue, this_arg: webidl.Opt(runtime.JSValue)) anyerror!void {
    const realm = instance.ctx;
    if (!engine.isCallable(realm, callback)) return error.TypeError;
    const function: engine.CallbackFunction = .{ .function = try engine.retainValue(realm, callback), .context = engine.incumbentRealm() };
    defer function.release();
    const receiver = try engine.retainValue(realm, this_arg.getOrDefault(.undefined));
    defer receiver.release();
    const internal = try internalOf(instance);
    const allocator = internal.values.allocator;
    internal.values.beginIteration();
    // A callback can retire this realm, freeing the Instance and its storage.
    defer if (realm.hasEngine()) internal.values.endIteration();
    var cursor: usize = 0;
    // WebIDL forEach steps 7–8 use the live SetData, including later appends.
    while (internal.values.next(&cursor)) |value| {
        const copy = try allocator.dupe(u8, value);
        defer allocator.free(copy);
        const js_value = runtime.JSValue.fromStringRef(copy);
        const completion = try engine.invokeCallbackFunction(realm, &function, .{ .value = receiver.value }, &.{ js_value, js_value, .{ .instance = instance } }, .rethrow);
        switch (completion) {
            .normal => |result| result.release(),
            .throw => |exception| {
                defer exception.release();
                if (realm.hasEngine()) try engine.throwValue(realm, exception.value);
                return error.ExceptionPending;
            },
        }
        if (!realm.hasEngine()) return;
    }
}
