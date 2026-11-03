//! How streams code keeps the objects it points at (streams_js.zig,
//! "Lifetime of the objects the reactions point at").
//!
//! `Realm.wrap` made an object's wrapper and let it go - right while the
//! wrapper cache kept every streams wrapper for its realm's life, and a
//! use-after-free for anything else (setUpController freed its
//! AbortController that way: encoding/streams/decode-bad-chunks.any.js in a
//! worker). Since lane streamslife1 no streams wrapper is held that way, so it
//! is gone: an argument names its instance (`Realm.instanceValue`, no wrapper
//! made), and pending work keeps what it touches with a `Hold`, a counted keep
//! given back exactly once - never to an object its realm's end freed.

const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const interfaces = @import("interfaces");
const js = @import("impls").Response.streams_js;

/// The test's agent: made by `open`, ended at the test's end.
var test_agent: test_process.TestAgent = .{};

test "Realm.instanceValue names an object for a call and makes no wrapper" {
    defer test_agent.close();
    _ = try test_agent.open(.{});
    const realm_ctx = try v8.context_manager.getOrCreate(test_agent.context.?, std.heap.page_allocator);

    const controller = try interfaces.AbortController.call_constructor(realm_ctx);
    // The test's to free, whole: nothing ever wrapped it.
    defer runtime.Instance.deinit(controller);
    const realm = try js.Realm.of(controller);
    const value = realm.instanceValue(controller);
    try std.testing.expect(value.value == .instance);
    try std.testing.expect(!engine.hasWrapper(controller));
}

test "a Hold is given back once, and never to an object freed under it" {
    defer test_agent.close();
    _ = try test_agent.open(.{});
    const realm_ctx = try v8.context_manager.getOrCreate(test_agent.context.?, std.heap.page_allocator);

    // Taken and given while the object lives: one keep, one release (an
    // unmatched release is an error log, which fails this test).
    const first = try interfaces.AbortController.call_constructor(realm_ctx);
    const hold = js.Hold.take(first);
    try std.testing.expect(hold.alive());
    hold.give();
    runtime.Instance.deinit(first);

    // Its object freed meanwhile - as a realm's end frees another realm's
    // stream under a pipe: no longer alive, and the give touches nothing.
    const second = try interfaces.AbortController.call_constructor(realm_ctx);
    const late = js.Hold.take(second);
    runtime.Instance.deinit(second);
    try std.testing.expect(!late.alive());
    late.give();
}
