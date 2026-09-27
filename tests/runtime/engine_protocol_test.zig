//! The engine protocol (`@import("engine")`, src/runtime/engine_protocol.zig)
//! bound to an adapter with no JavaScript engine behind it.
//!
//! This file is compiled once per such adapter, each in its own test binary
//! with no engine linked (build.zig, "Runtime tests"): the runtime tier's test
//! adapter (tests/runtime/protocol_test_adapter.zig), and the JavaScriptCore
//! and QuickJS protocol roots, which provide every operation as NotSupported
//! until they have an engine. Compiling it against each is what proves each
//! adapter conforms to the protocol - a missing or mis-typed operation fails
//! the build in the facade, naming the operation.
//!
//! The V8 binding of the same operations is tested at the end of
//! tests/v8/engine_runtime_impls_operations_test.zig.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");

fn noSteps(_: ?*anyopaque) void {
    unreachable;
}

test "an adapter with no engine answers NotSupported, never a guess" {
    var data = try runtime.ContextData.init(std.testing.allocator, .{});
    defer data.deinit();
    const realm: engine.Context = &data;

    try std.testing.expectError(error.NotSupported, engine.createResolvedPromise(realm, runtime.JSValue.jsUndefined));
    // The steps are never run: there is no engine to enter the realm in.
    try std.testing.expectError(error.NotSupported, engine.runTaskInRealm(realm, noSteps, null));
    // No script runs, so there is no current realm; nothing is callable.
    try std.testing.expectEqual(@as(?engine.Context, null), engine.currentRealm());
    try std.testing.expect(!engine.isCallable(runtime.JSValue.jsUndefined));
}

test "an Owned value is released through the adapter, or taken by whoever takes ownership" {
    const owned: engine.Owned = .{ .value = runtime.JSValue.fromNumber(7) };
    // take() hands the value on as it is - to the binding, which takes an
    // owned result - and leaves nothing to release.
    try std.testing.expectEqual(@as(f64, 7), owned.take().number);
    // release() is the adapter's releaseValue: a value that is not an
    // engine handle is left alone, so any Owned may be released.
    owned.release();
    engine.releaseValue(owned);
}

/// A caller of a capability-gated operation: the branch that calls it is
/// compiled only when the engine has the capability. Without the capability
/// the call would be a compile error ("engine.promiseIsHandled needs
/// engine.capabilities.promise_rejection_tracking ...").
fn handledOrUnknown(promise: engine.JSValue) ?bool {
    if (engine.capabilities.promise_rejection_tracking != .unsupported) return engine.promiseIsHandled(promise);
    return null;
}

test "a capability-gated operation compiles out where the engine lacks the capability" {
    // comptime-known: `if (engine.capabilities.X != .unsupported)` selects its
    // branch at compile time.
    comptime std.debug.assert(engine.capabilities.promise_rejection_tracking == .unsupported);
    try std.testing.expectEqual(@as(?bool, null), handledOrUnknown(runtime.JSValue.jsUndefined));
}

test "an adapter with no engine has none of the engine capabilities" {
    inline for (@typeInfo(engine.Capabilities).@"struct".fields) |field| {
        try std.testing.expectEqual(engine.Support.unsupported, @field(engine.capabilities, field.name));
    }
}

test "with no engine, a value's type and identity come from its IDL arm" {
    try std.testing.expectEqual(engine.ValueType.undefined, engine.typeOf(runtime.JSValue.jsUndefined));
    try std.testing.expectEqual(engine.ValueType.number, engine.typeOf(runtime.JSValue.fromNumber(1)));
    try std.testing.expectEqual(engine.ValueType.string, engine.typeOf(runtime.JSValue.fromStringRef("s")));
    // SameValue: NaN is NaN, +0 is not -0, strings by their code units.
    try std.testing.expect(engine.sameValue(runtime.JSValue.fromNumber(std.math.nan(f64)), runtime.JSValue.fromNumber(std.math.nan(f64))));
    try std.testing.expect(!engine.sameValue(runtime.JSValue.fromNumber(0.0), runtime.JSValue.fromNumber(-0.0)));
    try std.testing.expect(engine.sameValue(runtime.JSValue.fromStringRef("a"), runtime.JSValue.fromStringRef("a")));
    try std.testing.expect(!engine.sameValue(runtime.JSValue.fromStringRef("a"), runtime.JSValue.jsUndefined));
}

test "operations that make or run nothing answer NotSupported, and ones that cannot fail answer nothing" {
    var data = try runtime.ContextData.init(std.testing.allocator, .{});
    defer data.deinit();
    const realm: engine.Context = &data;
    try std.testing.expectError(error.NotSupported, engine.createPromise(realm));
    try std.testing.expectError(error.NotSupported, engine.convertToDOMString(realm, runtime.JSValue.jsUndefined, std.testing.allocator));
    try std.testing.expectError(error.NotSupported, engine.structuredDeserialize(realm, ""));
    try std.testing.expectEqual(@as(?engine.Context, null), engine.entryRealm());
    try std.testing.expectEqual(@as(?[]u8, null), engine.borrowArrayBufferBytes(runtime.JSValue.jsUndefined));
    // Nothing to check out: no microtasks without an engine.
    engine.performMicrotaskCheckpoint(realm);
}

test "the Agent a realm records is the one the protocol's agent operations take" {
    // requestGarbageCollection takes the realm's agent - here there is none
    // to collect, and the no-engine adapters do nothing.
    var agent_storage: u8 = 0;
    const agent: *engine.Agent = @ptrCast(&agent_storage);
    engine.requestGarbageCollection(agent);
}
