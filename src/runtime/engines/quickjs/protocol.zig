//! The QuickJS adapter's protocol root: module `engine_impl` in a
//! `-Dengine=quickjs` build, the functions the engine protocol
//! (src/runtime/engine_protocol.zig) forwards to.
//!
//! No engine is linked yet, so every operation is explicit: NotSupported
//! where it can fail, and the answer "nothing" where it cannot (no current
//! realm, nothing callable, nothing to release or collect) - AGENTS.md, "The
//! engine boundary". It declares none of the engine capabilities, and so
//! none of the operations that need one. tests/runtime/engine_protocol_test.zig
//! is compiled against this file, which is what checks it against the
//! protocol.

const engine = @import("engine");

pub const name = "QuickJS";

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
