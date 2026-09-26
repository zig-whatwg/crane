//! The V8 adapter's protocol root: module `engine_impl` in a V8 build, the
//! functions the engine protocol (src/runtime/engine_protocol.zig) forwards
//! to. Each has the protocol's signature exactly - the facade checks it.
//!
//! A module of its own, so it reaches the adapter through the `v8` module's
//! public surface, never by relative import: a file belongs to one module per
//! compilation, and every file beside this one belongs to `v8`.
//!
//! The operations wrap the adapter functions the runtime Engine table already
//! names. `v8_engine_interface` is comptime-known, so each `table.op.?` below
//! is a comptime-known function and the call to it is a direct call - the
//! protocol adds no dispatch. When the table goes, these call the same
//! functions by name.

const engine = @import("engine");
const v8 = @import("v8");
const ffi = v8.ffi;

const table = v8.engine.v8_engine_interface;

pub const name = "V8";

pub const capabilities: engine.Capabilities = .{
    .module_scripts = true,
    .promise_rejection_tracking = true,
    .reuse_window_proxy = true,
    .microtask_checkpoint_control = true,
    .exact_function_realm = true,
    .restores_snapshots = true,
    .can_block_control = true,
    .heap_statistics = true,
    .heap_snapshots = true,
    .diagnostic_counters = true,
};

pub fn currentRealm() ?engine.Context {
    return table.currentRealm.?();
}

pub fn isCallable(value: engine.JSValue) bool {
    return table.isCallable.?(value);
}

pub fn releaseValue(value: engine.Owned) void {
    table.releaseValue.?(value.value);
}

pub fn createResolvedPromise(realm: engine.Context, value: engine.JSValue) engine.Error!engine.Owned {
    return .{ .value = try table.createResolvedPromise.?(realm, value) };
}

pub fn runTaskInRealm(realm: engine.Context, steps: engine.RealmSteps, data: ?*anyopaque) engine.Error!void {
    return table.runTaskInRealm.?(realm, steps, data);
}

/// A realm's agent is its isolate (context_manager records it so).
/// LowMemoryNotification: a full, synchronous collection.
pub fn requestGarbageCollection(agent: *engine.Agent) void {
    ffi.v8_Isolate_RequestGarbageCollection(@ptrCast(agent));
}

/// A `.handle` is a Global either way it is tagged; anything else is not a
/// promise.
pub fn promiseIsHandled(promise: engine.JSValue) bool {
    const handle = switch (promise) {
        .handle => |h| h.ptr,
        else => return false,
    };
    return ffi.v8_Promise_HasHandler(@ptrCast(@alignCast(handle)));
}
