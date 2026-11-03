//! A platform object is wrapped only where a wrapper cache owns the wrapper.
//!
//! The wrapper `template_registry.wrapInstanceAsV8Object` makes is BORROWED
//! by every caller: the realm's wrapper cache holds it, and frees it with the
//! instance. In a context the context manager does not know - a realm whose
//! end has taken it out of the manager while its finalizers drain, or a
//! context no realm was made for - there was no cache to take it, and the
//! wrap made one anyway: a Global<Object> nothing ever disposed, an instance
//! marked wrapped for good (so the conservative paths kept its slot), and,
//! for a node, a NodeBase bound to a wrapper no cache would clear. tests-v8's
//! state survey (lane v8state1) found two: a byte stream and its controller
//! made by a body read dropped at its realm's end (microtask_dropped_end_test:
//! live_object_globals 0 -> 2) and a parent element node tracing wrapped in
//! a bare test context (teardown_gc_window_test: 0 -> 1). There the wrap now
//! answers no wrapper - what relevantWrapper's callers already handle (an
//! undefined), and what the realm's end expects ("a wrap answers undefined
//! and makes no wrapper"). Blink makes a wrapper only in a world with a
//! DOMDataStore to hold it (ToV8 -> DOMDataStore::SetWrapper).

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

/// The test's own agent, ended with the test (test_process.TestAgent).
var test_agent: test_process.TestAgent = .{};

test "a wrap in a context no realm was made for makes no wrapper and leaves no handle" {
    defer test_agent.close();
    const isolate = try test_agent.open(.{});
    // A realm's data for the agent's context, never registered with the
    // context manager: no wrapper cache the engine can find for it.
    const data = try test_agent.contextData(std.heap.page_allocator, .{ .engine_ctx = test_agent.context.? });
    data.agent = @ptrCast(isolate);

    const headers = try interfaces.Headers.init(testing.allocator, data);
    defer runtime.Instance.deinit(headers);

    // The agent's own isolate's global handles, every Global<Object> among
    // them - not the process's live_object_globals, which any other Browser
    // of the process moves (beside the many-Browsers variant's busy Browser it
    // read 0 -> 1 with no wrapper of this test's: lane tsanfix1).
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    if (protocol.retainValue(data, .{ .instance = headers })) |held| held.release() else |_| {}
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    if (after != before) {
        std.debug.print("the agent's global handle bytes {d} -> {d}: a wrapper no cache owns\n", .{ before, after });
        return error.WrapperLeaked;
    }
    // Nothing reached it, so its maker may free it whole.
    try testing.expect(!runtime.instance_lifecycle.wasWrapped(headers));
}
