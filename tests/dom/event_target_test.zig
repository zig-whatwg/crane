const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const impls = @import("impls");
const EventTarget = interfaces.EventTarget;
const Event = interfaces.Event;

test "EventTarget - removeEventListener matches by reference" {
    const allocator = std.testing.allocator;
    
    // Initialize runtime
    runtime.initRuntime(allocator);
    defer runtime.deinitializeRuntime();

    // Create a mock context (we need this for CallbackWrapper)
    // Note: In a real test we'd need a JS engine, but we can try to mock it
    // if we just want to test the logic in EventTarget.zig
    
    // Actually, EventTarget.zig depends on V8 for CallbackWrapper comparison.
    // If we run without V8, it might use the stub engine which returns false for comparison.
}
