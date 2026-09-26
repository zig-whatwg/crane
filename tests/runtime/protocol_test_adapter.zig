//! The engine protocol's test adapter: module `engine_impl` for the runtime
//! tier's tests (build.zig, "Runtime tests"), which bind the protocol here
//! and link no JavaScript engine. What the runtime Engine table's
//! `stub_engine` is to code that still reaches the table.
//!
//! Every operation is explicit: NotSupported where it can fail, and the answer
//! "nothing" where it cannot. It declares none of the engine capabilities,
//! and so none of the operations that need one.

const engine = @import("engine");

pub const name = "test";

pub const capabilities: engine.Capabilities = .{
    .module_scripts = false,
    .promise_rejection_tracking = false,
    .reuse_window_proxy = false,
    .microtask_checkpoint_control = false,
    .exact_function_realm = false,
    .restores_snapshots = false,
    .can_block_control = false,
    .heap_statistics = false,
    .heap_snapshots = false,
    .diagnostic_counters = false,
};

pub fn currentRealm() ?engine.Context {
    return null;
}

pub fn isCallable(_: engine.JSValue) bool {
    return false;
}

pub fn releaseValue(_: engine.Owned) void {}

pub fn createResolvedPromise(_: engine.Context, _: engine.JSValue) engine.Error!engine.Owned {
    return error.NotSupported;
}

pub fn runTaskInRealm(_: engine.Context, _: engine.RealmSteps, _: ?*anyopaque) engine.Error!void {
    return error.NotSupported;
}

pub fn requestGarbageCollection(_: *engine.Agent) void {}
