//! IndexedDB 4.1 request attributes and completion state.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const State = interfaces.IDBRequest.State;
pub const ImplError = error{InvalidStateError};
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    done: bool = false,
    result: runtime.JSValue = .jsUndefined,
    serialized_result: ?[]u8 = null,
    exception: ?*runtime.Instance = null,
    transaction: ?*runtime.Instance = null,
    source: ?*runtime.Instance = null,
};

pub fn installHooks() void {
    dom.indexeddb.installRequests(.{ .set_pending = setPending, .set_source = setSource, .complete_serialized = completeSerialized, .get_the_parent = getParent, .complete = completeRequest, .set_transaction = setTransaction });
}

pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.EventTarget.initWithState(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const state = instance.getState(State);
    state.own._internal = null;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    state.own._internal = internal;
    return instance;
}

pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.serialized_result) |bytes| internal.allocator.free(bytes);
        engine.forgetTracedChild(instance, .{ .name = "idb.result" });
        engine.forgetTracedChild(instance, .{ .name = "idb.error" });
        engine.forgetTracedChild(instance, .{ .name = "idb.transaction" });
        engine.forgetTracedChild(instance, .{ .name = "idb.source" });
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.EventTarget.deinit(instance);
}

fn completeRequest(instance: *runtime.Instance, result: runtime.JSValue, exception: ?*runtime.Instance) !void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    if (internal.serialized_result) |bytes| internal.allocator.free(bytes);
    internal.serialized_result = null;
    engine.forgetTracedChild(instance, .{ .name = "idb.result" });
    // 5.6.5.6: keep the operation's result itself, including arrays containing
    // IDBRecords. Serializing it again would discard identity or reject records.
    internal.result = switch (result) {
        .undefined, .null, .number, .boolean, .instance => result,
        else => .jsUndefined,
    };
    switch (result) {
        .instance => |child| engine.traceChild(instance, child, .{ .name = "idb.result" }),
        .undefined, .null, .number, .boolean => {},
        else => engine.traceValue(instance, result, .{ .name = "idb.result" }),
    }
    internal.exception = exception;
    engine.forgetTracedChild(instance, .{ .name = "idb.error" });
    if (exception) |child| engine.traceChild(instance, child, .{ .name = "idb.error" });
    internal.done = true;
}

fn setTransaction(instance: *runtime.Instance, transaction: ?*runtime.Instance) void {
    const internal = instance.getState(State).own._internal orelse return;
    internal.transaction = transaction;
    engine.forgetTracedChild(instance, .{ .name = "idb.transaction" });
    if (transaction) |child| engine.traceChild(instance, child, .{ .name = "idb.transaction" });
}

pub fn get_result(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    // Result getter step 1: a pending request has no observable result.
    if (!internal.done) return error.InvalidStateError;
    // Step 2: errors have undefined as their result; the binding owns its hold.
    return readResult(instance, internal);
}
pub fn get_error(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    // Error getter step 1, then step 2.
    if (!internal.done) return error.InvalidStateError;
    return internal.exception;
}
pub fn get_source(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return if (internal.source) |source| .{ .instance = source } else null;
}
pub fn get_transaction(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return internal.transaction;
}
pub fn get_readyState(instance: *runtime.Instance) anyerror!enums.IDBRequestReadyState {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return if (internal.done) ._done_ else ._pending_;
}
pub fn get_onsuccess(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "success");
}
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "error");
}
pub fn set_onsuccess(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "success", value);
}
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "error", value);
}

fn getParent(instance: *runtime.Instance) ?*runtime.Instance {
    return (instance.getState(State).own._internal orelse return null).transaction;
}

/// 4.1 result getter: repeated reads return the same value, with a traced edge
/// so a result that refers to this request does not become a rooted cycle.
fn readResult(instance: *runtime.Instance, internal: *InternalState) !runtime.JSValue {
    if (engine.tracedValue(instance, .{ .name = "idb.result" })) |value| return value.take();
    if (internal.serialized_result) |bytes| {
        const value = try engine.structuredDeserialize(instance.ctx, bytes);
        engine.traceValue(instance, value.value, .{ .name = "idb.result" });
        return value.take();
    }
    return (try engine.retainValue(instance.ctx, internal.result)).take();
}

fn setPending(instance: *runtime.Instance) void {
    (instance.getState(State).own._internal orelse return).done = false;
}
fn setSource(instance: *runtime.Instance, source: ?*runtime.Instance) void {
    const internal = instance.getState(State).own._internal orelse return;
    internal.source = source;
    engine.forgetTracedChild(instance, .{ .name = "idb.source" });
    if (source) |child| engine.traceChild(instance, child, .{ .name = "idb.source" });
}
fn completeSerialized(instance: *runtime.Instance, bytes: []const u8) !void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const copy = try internal.allocator.dupe(u8, bytes);
    errdefer internal.allocator.free(copy);
    try completeRequest(instance, .jsUndefined, null);
    internal.serialized_result = copy;
}
