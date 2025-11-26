//! Instance Initialization Tests
//!
//! Tests to verify proper memory initialization in runtime.Instance.init()
//! and prevent uninitialized memory bugs.
//!
//! **Critical Bug Prevention**: These tests ensure state memory is zero-initialized
//! to prevent crashes from garbage pointer values.
//!
//! Reference: Memory initialization bug analysis in tmp/analysis/memory_initialization_bug_analysis.md

const std = @import("std");
const runtime = @import("runtime");
const testing = std.testing;

/// Test state struct with various field types
const TestState = struct {
    // Optional pointer - MUST be null when initialized
    optional_ptr: ?*u32 = null,

    // Optional instance - MUST be null when initialized
    optional_instance: ?*runtime.Instance = null,

    // Boolean - MUST be false when initialized
    flag: bool = false,

    // Integer - MUST be 0 when initialized
    counter: u32 = 0,

    // Float - MUST be 0.0 when initialized
    ratio: f64 = 0.0,

    // Array - MUST be all zeros when initialized
    buffer: [16]u8 = [_]u8{0} ** 16,
};

/// Empty delegates struct for testing
const TestDelegates = struct {};
const test_delegates = TestDelegates{};

/// Test VTable for TestState
const test_vtable = runtime.VTable{
    .deinit = null,
    .methods_ptr = &test_delegates,
};

test "Instance.init - state memory is zero-initialized" {
    const allocator = testing.allocator;

    // Initialize allocators required by Instance.init
    runtime.SlabAllocator.init(allocator);
    runtime.ArenaAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    defer runtime.ArenaAllocator.deinit();

    // Create mock context
    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();

    const ctx: runtime.Context = &ctx_data;

    // Create instance with TestState
    const instance = try runtime.Instance.init(allocator, TestState, &test_vtable, ctx);
    defer runtime.Instance.deinit(instance);

    const state = instance.getState(TestState);

    // Verify all fields are properly initialized to zero/null/false
    try testing.expectEqual(@as(?*u32, null), state.optional_ptr);
    try testing.expectEqual(@as(?*runtime.Instance, null), state.optional_instance);
    try testing.expectEqual(false, state.flag);
    try testing.expectEqual(@as(u32, 0), state.counter);
    try testing.expectEqual(@as(f64, 0.0), state.ratio);

    // Verify buffer is all zeros
    for (state.buffer) |byte| {
        try testing.expectEqual(@as(u8, 0), byte);
    }
}

test "Instance.init - optional fields don't contain garbage" {
    const allocator = testing.allocator;

    runtime.SlabAllocator.init(allocator);
    runtime.ArenaAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    defer runtime.ArenaAllocator.deinit();

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();

    const ctx: runtime.Context = &ctx_data;

    // Create multiple instances to increase chance of non-zero memory
    var instances: [10]*runtime.Instance = undefined;
    defer for (instances) |inst| runtime.Instance.deinit(inst);

    for (&instances) |*inst| {
        inst.* = try runtime.Instance.init(allocator, TestState, &test_vtable, ctx);
        const state = inst.*.getState(TestState);

        // CRITICAL: Optional pointers MUST be null, not garbage
        // Before the fix, these would contain 0xaaaaaaaaaaaaaaaa or similar
        try testing.expectEqual(@as(?*u32, null), state.optional_ptr);
        try testing.expectEqual(@as(?*runtime.Instance, null), state.optional_instance);
    }
}

test "Instance.init - numeric fields are zero" {
    const allocator = testing.allocator;

    runtime.SlabAllocator.init(allocator);
    runtime.ArenaAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    defer runtime.ArenaAllocator.deinit();

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();

    const ctx: runtime.Context = &ctx_data;

    const instance = try runtime.Instance.init(allocator, TestState, &test_vtable, ctx);
    defer runtime.Instance.deinit(instance);

    const state = instance.getState(TestState);

    // All numeric fields must be zero-initialized
    try testing.expectEqual(@as(u32, 0), state.counter);
    try testing.expectEqual(@as(f64, 0.0), state.ratio);
}

test "Instance.init - boolean fields are false" {
    const allocator = testing.allocator;

    runtime.SlabAllocator.init(allocator);
    runtime.ArenaAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    defer runtime.ArenaAllocator.deinit();

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();

    const ctx: runtime.Context = &ctx_data;

    const instance = try runtime.Instance.init(allocator, TestState, &test_vtable, ctx);
    defer runtime.Instance.deinit(instance);

    const state = instance.getState(TestState);

    // Boolean must be false-initialized
    try testing.expectEqual(false, state.flag);
}

test "Instance.init - array fields are zeroed" {
    const allocator = testing.allocator;

    runtime.SlabAllocator.init(allocator);
    runtime.ArenaAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    defer runtime.ArenaAllocator.deinit();

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();

    const ctx: runtime.Context = &ctx_data;

    const instance = try runtime.Instance.init(allocator, TestState, &test_vtable, ctx);
    defer runtime.Instance.deinit(instance);

    const state = instance.getState(TestState);

    // Every byte in the array must be zero
    for (state.buffer, 0..) |byte, i| {
        try testing.expectEqual(@as(u8, 0), byte);
        _ = i; // unused in error message but useful for debugging
    }
}

// Regression test: Simulate the Document.implementation crash scenario
test "Instance.init - regression test for cached property crash" {
    const allocator = testing.allocator;

    runtime.SlabAllocator.init(allocator);
    runtime.ArenaAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    defer runtime.ArenaAllocator.deinit();

    // Simulate a WebIDL interface state with cached properties
    const DocumentLikeState = struct {
        cached_implementation: ?*runtime.Instance = null,
        cached_element: ?*runtime.Instance = null,
        document_url: []const u8 = "",
    };

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();

    const ctx: runtime.Context = &ctx_data;

    const instance = try runtime.Instance.init(allocator, DocumentLikeState, &test_vtable, ctx);
    defer runtime.Instance.deinit(instance);

    const state = instance.getState(DocumentLikeState);

    // CRITICAL: This is the pattern that crashed before the fix
    // Optional unwrap would treat garbage pointers as valid
    if (state.cached_implementation) |cached| {
        // If we get here with a non-null cached value, it MUST be a valid pointer
        // Before the fix, this would be garbage (0xaaaaaaaaaaaaaaaa) and crash
        _ = cached;
        try testing.expect(false); // Should never reach here with null default
    } else {
        // This is correct - cached field should be null initially
        try testing.expect(true);
    }

    // Same for other cached fields
    try testing.expectEqual(@as(?*runtime.Instance, null), state.cached_element);
}

test "Instance.init - large state is fully zeroed" {
    const allocator = testing.allocator;

    runtime.SlabAllocator.init(allocator);
    runtime.ArenaAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    defer runtime.ArenaAllocator.deinit();

    // Test with a larger state (similar to Document which has ~2KB state)
    const LargeState = struct {
        cached_fields: [64]?*runtime.Instance = [_]?*runtime.Instance{null} ** 64,
        counters: [128]u32 = [_]u32{0} ** 128,
        flags: [256]bool = [_]bool{false} ** 256,
    };

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();

    const ctx: runtime.Context = &ctx_data;

    const instance = try runtime.Instance.init(allocator, LargeState, &test_vtable, ctx);
    defer runtime.Instance.deinit(instance);

    const state = instance.getState(LargeState);

    // Verify ALL cached fields are null
    for (state.cached_fields) |cached| {
        try testing.expectEqual(@as(?*runtime.Instance, null), cached);
    }

    // Verify ALL counters are zero
    for (state.counters) |counter| {
        try testing.expectEqual(@as(u32, 0), counter);
    }

    // Verify ALL flags are false
    for (state.flags) |flag| {
        try testing.expectEqual(false, flag);
    }
}

test "Instance.init - no memory leaks" {
    const allocator = testing.allocator;

    runtime.SlabAllocator.init(allocator);
    runtime.ArenaAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    defer runtime.ArenaAllocator.deinit();

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();

    const ctx: runtime.Context = &ctx_data;

    // Create and destroy many instances
    // testing.allocator will detect any leaks
    for (0..100) |_| {
        const instance = try runtime.Instance.init(allocator, TestState, &test_vtable, ctx);
        runtime.Instance.deinit(instance);
    }
}
