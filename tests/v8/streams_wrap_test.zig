//! streams_js.Realm.wrap takes only what the wrapper cache holds strongly.
//!
//! `Realm.wrap` makes an object's wrapper and lets it go: right for a
//! streams-graph object, whose wrapper the cache keeps for the realm's life,
//! and a use-after-free for anything else. setUpController wrapped its
//! AbortController and cloned the result a step later; a collection in
//! between freed the AbortController (the worker variant of
//! encoding/streams/decode-bad-chunks.any.js crashed). Now wrap refuses
//! anything outside the one allowlist the wrapper cache also reads.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const interfaces = @import("interfaces");
const js = @import("impls").Response.streams_js;
const ffi = v8.ffi;

test "the streams-graph allowlist: streams classes in, weak classes out" {
    for (js.streams_graph_classes) |name| try std.testing.expect(js.isStreamsGraphObject(name));
    for ([_][]const u8{ "AbortController", "AbortSignal", "TextDecoderStream", "TextEncoderStream", "Window", "Event", "" }) |name| {
        try std.testing.expect(!js.isStreamsGraphObject(name));
    }
}

test "the wrapper cache reads the same allowlist" {
    for (js.streams_graph_classes) |name| try std.testing.expect(v8.wrapper_cache_mod.isStreamsGraphObject(name));
    for ([_][]const u8{ "AbortController", "AbortSignal", "Node", "" }) |name| {
        try std.testing.expect(!v8.wrapper_cache_mod.isStreamsGraphObject(name));
    }
}

test "Realm.wrap refuses an AbortController - its wrapper is weak, so it is held with clone" {
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(isolate);
    _ = ffi.v8_HandleScope_New(isolate);
    const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    v8.context_manager.init(std.heap.page_allocator) catch {};
    const realm_ctx = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);

    const controller = try interfaces.AbortController.call_constructor(realm_ctx);
    const realm = try js.Realm.of(controller);
    try std.testing.expectError(error.NotAStreamsGraphObject, realm.wrap(controller));
}
