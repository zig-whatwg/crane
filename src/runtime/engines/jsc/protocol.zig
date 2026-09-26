//! The JavaScriptCore adapter's protocol root: module `engine_impl` in a
//! `-Dengine=jsc` build, the functions the engine protocol
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

pub const name = "JavaScriptCore";

/// What the public JavaScriptCore C API offers. The first three were
/// requested of Apple and WebKit on 2026-09-26: flip each when an iOS release
/// makes its API public.
pub const capabilities: engine.Capabilities = .{
    // No module loader in the public API: FB24953657,
    // https://bugs.webkit.org/show_bug.cgi?id=191121#c31
    .module_scripts = false,
    // No public promise rejection tracker: FB24953666,
    // https://bugs.webkit.org/show_bug.cgi?id=197172#c60
    .promise_rejection_tracking = false,
    // No global proxy distinct from the global: FB24953676,
    // https://bugs.webkit.org/show_bug.cgi?id=325379
    .reuse_window_proxy = false,
    // JSC drains microtasks when its outermost call returns.
    .microtask_checkpoint_control = false,
    // GetFunctionRealm is SPI.
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
