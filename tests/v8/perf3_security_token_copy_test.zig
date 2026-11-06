//! A ShadowRealm's context takes its initiator's security token without a
//! handle left behind.
//!
//! `new ShadowRealm()` reaches shadow_realm.zig's context callback, which
//! gives the new context the initiator context's security token so that V8's
//! MayAccess lets `new Function()` run inside it. It read the token through
//! `v8_Context_GetSecurityToken`, which returns a new Global<Value> the
//! caller owns (every `v8_*` return is owned: src/AGENTS.md "Memory"), and
//! never released it: one 16 B box and one V8 global-handle node per
//! ShadowRealm, for the agent's life. leaks --atExit over the DOM lifetime
//! list, web-animations/ and css/css-transitions/ rooted all 148 of main's
//! leaks there (lane anim1, 2026-11-06; feature-queue "HIGH LEAK").
//!
//! The step is `shadow_realm.inheritSecurityToken`; this test runs it the way
//! the callback does, over two contexts of one agent, and reads V8's own live
//! count (`v8_Isolate_GetGlobalHandleBytes`) - a ShadowRealm needs an agent
//! restored from the snapshot, which only the first file of a process may
//! start (agents_concurrent_engine_state_test.zig), and the copy is the whole
//! of the leak.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const v8 = @import("v8");
const ffi = v8.ffi;

/// The test's own agent, ended with the test (test_process.TestAgent).
var test_agent: test_process.TestAgent = .{};

test "a ShadowRealm's context takes its initiator's security token and keeps no handle" {
    const isolate = try test_agent.open(.{});
    defer test_agent.close();
    const initiator = test_agent.context.?;
    const shadow = ffi.v8_Context_New(isolate) orelse return error.NoContext;
    defer ffi.v8_Context_Dispose(shadow);

    // Warm-up: what the first copies make and later ones reuse is not counted.
    for (0..32) |_| v8.shadow_realm.inheritSecurityToken(shadow, initiator);
    const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
    for (0..512) |_| v8.shadow_realm.inheritSecurityToken(shadow, initiator);
    const after: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
    // 512 copies keeping their token handle would be 8,192 bytes or more.
    try testing.expect(after - before < 2048);

    // The token IS the initiator's: the two contexts now share one value.
    const initiator_token = ffi.v8_Context_GetSecurityToken(initiator) orelse return error.NoToken;
    defer ffi.v8_Value_Dispose(initiator_token);
    const shadow_token = ffi.v8_Context_GetSecurityToken(shadow) orelse return error.NoToken;
    defer ffi.v8_Value_Dispose(shadow_token);
    try testing.expect(ffi.v8_Value_StrictEquals(initiator_token, shadow_token));
}
