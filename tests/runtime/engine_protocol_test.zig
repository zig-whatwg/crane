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
    try std.testing.expect(!engine.isCallable(realm, runtime.JSValue.jsUndefined));
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

test "undefined, null, a boolean or a number is retained by value, with no engine behind the realm" {
    var data = try runtime.ContextData.init(std.testing.allocator, .{});
    defer data.deinit();
    const realm: engine.Context = &data;
    // They hold no engine resource: nothing is entered, so a realm with no
    // engine retains them too, and releasing one does nothing.
    for ([_]runtime.JSValue{ runtime.JSValue.jsUndefined, runtime.JSValue.jsNull, runtime.JSValue.fromBoolean(true), runtime.JSValue.fromNumber(-0.0) }) |value| {
        const held = try engine.retainValue(realm, value);
        defer held.release();
        try std.testing.expectEqual(std.meta.activeTag(value), std.meta.activeTag(held.value));
    }
    const number = try engine.retainValue(realm, runtime.JSValue.fromNumber(2.5));
    try std.testing.expectEqual(@as(f64, 2.5), number.value.number);
    // A string is an engine value to hold: that needs the engine.
    try std.testing.expectError(error.NotSupported, engine.retainValue(realm, runtime.JSValue.fromStringRef("s")));
}

test "borrow is a view of an Owned value that its holder keeps, and the binding leaves" {
    var slot: u8 = 0;
    const handle: engine.Owned = .{ .value = runtime.JSValue.fromHandle(@ptrCast(&slot)) };
    const view = handle.borrow();
    // The same engine value, never to be released by whoever receives it.
    try std.testing.expectEqual(@as(*anyopaque, @ptrCast(&slot)), view.handle.ptr);
    try std.testing.expect(!view.needsDisposal());
    try std.testing.expect(handle.value.needsDisposal());

    const text: engine.Owned = .{ .value = runtime.JSValue.fromStringOwned("kept") };
    try std.testing.expect(!text.borrow().needsDisposal());
    try std.testing.expectEqualStrings("kept", text.borrow().string.data);

    const number: engine.Owned = .{ .value = runtime.JSValue.fromNumber(3) };
    try std.testing.expectEqual(@as(f64, 3), number.borrow().number);
}

test "ToBoolean of every IDL arm, with no engine behind the realm" {
    var data = try runtime.ContextData.init(std.testing.allocator, .{});
    defer data.deinit();
    const realm: engine.Context = &data;
    // ECMAScript 7.1.2: undefined, null, false, +0, -0, NaN and "" are false.
    for ([_]runtime.JSValue{
        runtime.JSValue.jsUndefined,
        runtime.JSValue.jsNull,
        runtime.JSValue.fromBoolean(false),
        runtime.JSValue.fromNumber(0.0),
        runtime.JSValue.fromNumber(-0.0),
        runtime.JSValue.fromNumber(std.math.nan(f64)),
        runtime.JSValue.fromStringRef(""),
    }) |value| try std.testing.expect(!engine.toBoolean(realm, value));
    // Everything else is true - an object (a platform object) always.
    var instance: runtime.Instance = undefined;
    for ([_]runtime.JSValue{
        runtime.JSValue.fromBoolean(true),
        runtime.JSValue.fromNumber(-1),
        runtime.JSValue.fromNumber(std.math.inf(f64)),
        runtime.JSValue.fromStringRef("0"),
        .{ .instance = &instance },
    }) |value| try std.testing.expect(engine.toBoolean(realm, value));
}

/// A caller of a capability-gated operation: the branch that calls it is
/// compiled only when the engine has the capability. Without the capability
/// the call would be a compile error ("engine.promiseIsHandled needs
/// engine.capabilities.promise_rejection_tracking ...").
fn handledOrUnknown(realm: engine.Context, promise: engine.JSValue) ?bool {
    if (engine.capabilities.promise_rejection_tracking != .unsupported) return engine.promiseIsHandled(realm, promise);
    return null;
}

test "a capability-gated operation compiles out where the engine lacks the capability" {
    // comptime-known: `if (engine.capabilities.X != .unsupported)` selects its
    // branch at compile time.
    comptime std.debug.assert(engine.capabilities.promise_rejection_tracking == .unsupported);
    var data = try runtime.ContextData.init(std.testing.allocator, .{});
    defer data.deinit();
    try std.testing.expectEqual(@as(?bool, null), handledOrUnknown(&data, runtime.JSValue.jsUndefined));
}

test "an adapter with no engine has none of the engine capabilities" {
    inline for (@typeInfo(engine.Capabilities).@"struct".fields) |field| {
        try std.testing.expectEqual(engine.Support.unsupported, @field(engine.capabilities, field.name));
    }
}

test "with no engine, a value's type and identity come from its IDL arm" {
    var data = try runtime.ContextData.init(std.testing.allocator, .{});
    defer data.deinit();
    const realm: engine.Context = &data;
    try std.testing.expectEqual(engine.ValueType.undefined, engine.typeOf(realm, runtime.JSValue.jsUndefined));
    try std.testing.expectEqual(engine.ValueType.number, engine.typeOf(realm, runtime.JSValue.fromNumber(1)));
    try std.testing.expectEqual(engine.ValueType.string, engine.typeOf(realm, runtime.JSValue.fromStringRef("s")));
    // SameValue: NaN is NaN, +0 is not -0, strings by their code units.
    try std.testing.expect(engine.sameValue(realm, runtime.JSValue.fromNumber(std.math.nan(f64)), runtime.JSValue.fromNumber(std.math.nan(f64))));
    try std.testing.expect(!engine.sameValue(realm, runtime.JSValue.fromNumber(0.0), runtime.JSValue.fromNumber(-0.0)));
    try std.testing.expect(engine.sameValue(realm, runtime.JSValue.fromStringRef("a"), runtime.JSValue.fromStringRef("a")));
    try std.testing.expect(!engine.sameValue(realm, runtime.JSValue.fromStringRef("a"), runtime.JSValue.jsUndefined));
}

test "operations that make or run nothing answer NotSupported, and ones that cannot fail answer nothing" {
    var data = try runtime.ContextData.init(std.testing.allocator, .{});
    defer data.deinit();
    const realm: engine.Context = &data;
    try std.testing.expectError(error.NotSupported, engine.createPromise(realm));
    try std.testing.expectError(error.NotSupported, engine.convertToDOMString(realm, runtime.JSValue.jsUndefined, std.testing.allocator));
    try std.testing.expectError(error.NotSupported, engine.structuredDeserialize(realm, ""));
    try std.testing.expectEqual(@as(?engine.Context, null), engine.entryRealm());
    try std.testing.expectEqual(@as(?[]u8, null), engine.borrowArrayBufferBytes(realm, runtime.JSValue.jsUndefined));
    // Nothing to check out: no microtasks without an engine.
    var agent_storage: u8 = 0;
    try engine.performMicrotaskCheckpoint(@ptrCast(&agent_storage));
}

test "the Agent a realm records is the one the protocol's agent operations take" {
    // requestGarbageCollection takes the realm's agent - here there is none
    // to collect, and the no-engine adapters do nothing.
    var agent_storage: u8 = 0;
    const agent: *engine.Agent = @ptrCast(&agent_storage);
    engine.requestGarbageCollection(agent);
}
