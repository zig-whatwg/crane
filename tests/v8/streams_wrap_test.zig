//! streams_js.Realm.wrap takes only what the wrapper cache holds strongly.
//!
//! `Realm.wrap` makes an object's wrapper and lets it go: right for a
//! streams-graph object, whose wrapper the cache keeps for the realm's life,
//! and a use-after-free for anything else. setUpController wrapped its
//! AbortController and cloned the result a step later; a collection in
//! between freed the AbortController (the worker variant of
//! encoding/streams/decode-bad-chunks.any.js crashed). Now wrap refuses
//! anything outside runtime.streams_graph, the list the wrapper cache also reads.

const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const v8 = @import("v8");
const interfaces = @import("interfaces");
const js = @import("impls").Response.streams_js;

test "the wrapper cache reads the runtime's streams graph" {
    for (runtime.streams_graph.streams_graph_classes) |name| try std.testing.expect(v8.wrapper_cache_mod.isStreamsGraphObject(name));
    for ([_][]const u8{ "AbortController", "AbortSignal", "Node", "" }) |name| {
        try std.testing.expect(!v8.wrapper_cache_mod.isStreamsGraphObject(name));
    }
}

/// The test's agent: made by `open`, ended at the test's end.
var test_agent: test_process.TestAgent = .{};

test "Realm.wrap refuses an AbortController - its wrapper is weak, so it is held with clone" {
    defer test_agent.close();
    _ = try test_agent.open(.{});
    const realm_ctx = try v8.context_manager.getOrCreate(test_agent.context.?, std.heap.page_allocator);

    const controller = try interfaces.AbortController.call_constructor(realm_ctx);
    // The test's to free, whole (its signal with it): wrap refused, nothing
    // else ever held it.
    defer runtime.Instance.deinit(controller);
    const realm = try js.Realm.of(controller);
    try std.testing.expectError(error.NotAStreamsGraphObject, realm.wrap(controller));
    try std.testing.expect(!@import("engine").hasWrapper(controller));
}
