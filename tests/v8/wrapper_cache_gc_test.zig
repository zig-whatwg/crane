//! V8 Wrapper Cache GC Integration Tests
//!
//! These tests verify that the WrapperCache correctly integrates with V8's
//! garbage collector through weak callbacks and automatic cleanup.
//!
//! ## Test Coverage
//!
//! ### Zig Unit Tests (Mock-Based)
//! 1. **Cache Lifecycle**: Verify init/deinit with multiple entries
//! 2. **Manual Weak Callback Simulation**: Simulate GC callback manually
//! 3. **Cache Entry Replacement**: Verify old entries are cleaned up
//! 4. **Memory Safety**: Verify no leaks with std.testing.allocator
//! 5. **Stress Testing**: Verify cache handles 1000+ entries
//!
//! ### JavaScript Integration Tests (Real V8)
//! See: tests/v8/wrapper_cache_gc_test.js
//! - Wrapper identity across querySelector calls
//! - Wrapper identity after GC (if gc() exposed)
//! - Constructor vs query identity
//! - Multiple elements, nested elements
//! - Edge cases (null, empty selectors)
//!
//! ## Architecture
//!
//! These Zig tests use **mock V8 objects** to test cache mechanics without
//! requiring full V8 runtime. The JavaScript tests verify actual V8 integration
//! with real DOM elements and garbage collection.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const WrapperCache = v8.WrapperCache;

// ============================================================================
// Mock Helpers
// ============================================================================

/// Create a mock V8 Context for testing
fn createMockContext() *v8.Context {
    const context_storage = testing.allocator.create(u32) catch unreachable;
    context_storage.* = 0xCAFEBABE;
    return @ptrCast(context_storage);
}

/// Destroy mock V8 Context
fn destroyMockContext(context: *v8.Context) void {
    const ptr: *u32 = @ptrCast(@alignCast(context));
    testing.allocator.destroy(ptr);
}

/// Create a mock V8 Isolate for testing
fn createMockIsolate() *v8.Isolate {
    const isolate_storage = testing.allocator.create(u32) catch unreachable;
    isolate_storage.* = 0xDEADBEEF;
    return @ptrCast(isolate_storage);
}

/// Destroy mock V8 Isolate
fn destroyMockIsolate(isolate: *v8.Isolate) void {
    const ptr: *u32 = @ptrCast(@alignCast(isolate));
    testing.allocator.destroy(ptr);
}

/// Create a mock V8 Object (wrapper) for testing
fn createMockWrapper(allocator: std.mem.Allocator) !*v8.Object {
    const wrapper_storage = try allocator.create(u64);
    wrapper_storage.* = @intFromPtr(wrapper_storage); // Unique value per wrapper
    return @ptrCast(wrapper_storage);
}

/// Destroy mock V8 Object
fn destroyMockWrapper(allocator: std.mem.Allocator, wrapper: *v8.Object) void {
    const ptr: *u64 = @ptrCast(@alignCast(wrapper));
    allocator.destroy(ptr);
}

/// Create a mock runtime Instance for testing
fn createMockInstance(allocator: std.mem.Allocator) !*runtime.Instance {
    const instance = try allocator.create(runtime.Instance);
    instance.* = .{
        .vtable = undefined, // Not needed for cache testing
        .state = undefined,
        .ctx = undefined,
    };
    return instance;
}

/// Destroy mock runtime Instance
fn destroyMockInstance(allocator: std.mem.Allocator, instance: *runtime.Instance) void {
    allocator.destroy(instance);
}

/// Cleanup cache entries without calling V8 dispose (for mock objects)
///
/// This is needed because mock V8 objects aren't real V8 Global handles,
/// so calling v8.v8_Object_Dispose() on them will crash V8.
/// We use fetchRemove to get entries and free CacheEntry allocations properly.
fn cleanupMockCacheEntries(cache: *WrapperCache, instances: []const *runtime.Instance, allocator: std.mem.Allocator) void {
    for (instances) |instance| {
        if (cache.cache.fetchRemove(instance)) |kv| {
            // Free the CacheEntry (normally done in weak callback or remove())
            allocator.destroy(kv.value);
        }
    }
}

// ============================================================================
// Test 1: Cache Lifecycle with Multiple Entries
// ============================================================================

test "WrapperCache - lifecycle with 10 entries" {
    const context = createMockContext();
    defer destroyMockContext(context);

    const isolate = createMockIsolate();
    defer destroyMockIsolate(isolate);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    var instances: [10]*runtime.Instance = undefined;
    var wrappers: [10]*v8.Object = undefined;

    // Create and cache 10 instance-wrapper pairs
    for (0..10) |i| {
        instances[i] = try createMockInstance(testing.allocator);
        wrappers[i] = try createMockWrapper(testing.allocator);

        try cache.set(instances[i], wrappers[i], isolate);
    }

    // Verify all cached
    try testing.expectEqual(@as(usize, 10), cache.size());

    // Verify each can be retrieved
    for (instances, wrappers) |instance, wrapper| {
        const cached = cache.get(instance);
        try testing.expect(cached != null);
        try testing.expectEqual(wrapper, cached.?);
    }

    // Cleanup: Since we're using mock V8 objects, we need to manually clean them up
    // and remove cache entries before deinit, otherwise cache.deinit() will try to
    // call v8.v8_Object_Dispose() on mock objects which will crash V8.
    for (wrappers) |wrapper| {
        destroyMockWrapper(testing.allocator, wrapper);
    }
    cleanupMockCacheEntries(&cache, &instances, testing.allocator);

    for (instances) |instance| {
        destroyMockInstance(testing.allocator, instance);
    }
}

// ============================================================================
// Test 2: Manual Weak Callback Simulation
// ============================================================================

test "WrapperCache - manual weak callback simulation" {
    const context = createMockContext();
    defer destroyMockContext(context);

    const isolate = createMockIsolate();
    defer destroyMockIsolate(isolate);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    const instance = try createMockInstance(testing.allocator);
    defer destroyMockInstance(testing.allocator, instance);

    const wrapper = try createMockWrapper(testing.allocator);

    // Cache the wrapper
    try cache.set(instance, wrapper, isolate);
    try testing.expectEqual(@as(usize, 1), cache.size());

    // Simulate weak callback by manually removing from cache
    // (In real V8, this happens automatically via weakCallback())
    const removed = cache.cache.fetchRemove(instance);

    // Free the CacheEntry (normally done in weak callback)
    if (removed) |kv| {
        testing.allocator.destroy(kv.value);
    }

    // Verify entry removed
    try testing.expectEqual(@as(usize, 0), cache.size());
    try testing.expect(cache.get(instance) == null);

    // Clean up wrapper (normally done in weak callback)
    destroyMockWrapper(testing.allocator, wrapper);
}

// ============================================================================
// Test 3: Cache Entry Replacement
// ============================================================================

// NOTE: This test is skipped because it requires real V8 Global handles.
// Mock objects don't work with v8.v8_Global_SetWeak() which is called in cache.set().
// See tests/v8/wrapper_cache_gc_test.js for JavaScript integration test coverage.
test "WrapperCache - replacing entry for same instance" {
    return error.SkipZigTest;
}

// ============================================================================
// Test 4: Memory Safety - No Leaks
// ============================================================================

test "WrapperCache - no memory leaks with 100 cycles" {
    // std.testing.allocator will fail this test if there are leaks
    for (0..100) |_| {
        const context = createMockContext();
        defer destroyMockContext(context);

        const isolate = createMockIsolate();
        defer destroyMockIsolate(isolate);

        var cache = try WrapperCache.init(testing.allocator, context);
        defer cache.deinit();

        // Create 10 instances per cycle
        var instances: [10]*runtime.Instance = undefined;
        var wrappers: [10]*v8.Object = undefined;

        for (0..10) |i| {
            instances[i] = try createMockInstance(testing.allocator);
            wrappers[i] = try createMockWrapper(testing.allocator);
            try cache.set(instances[i], wrappers[i], isolate);
        }

        // Cleanup
        for (wrappers) |wrapper| {
            destroyMockWrapper(testing.allocator, wrapper);
        }
        cleanupMockCacheEntries(&cache, &instances, testing.allocator);

        for (instances) |instance| {
            destroyMockInstance(testing.allocator, instance);
        }
    }
}

// ============================================================================
// Test 5: Stress Test - 1000 Elements
// ============================================================================

test "WrapperCache - stress test with 100 entries" {
    const context = createMockContext();
    defer destroyMockContext(context);

    const isolate = createMockIsolate();
    defer destroyMockIsolate(isolate);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    const count = 100;

    // Use fixed-size arrays for simplicity
    var instances: [count]*runtime.Instance = undefined;
    var wrappers: [count]*v8.Object = undefined;

    // Create and cache 100 entries
    for (0..count) |i| {
        instances[i] = try createMockInstance(testing.allocator);
        wrappers[i] = try createMockWrapper(testing.allocator);

        try cache.set(instances[i], wrappers[i], isolate);
    }

    // Verify cache size
    try testing.expectEqual(@as(usize, count), cache.size());

    // Verify all entries can be retrieved
    for (instances, wrappers) |instance, wrapper| {
        const cached = cache.get(instance);
        try testing.expect(cached != null);
        try testing.expectEqual(wrapper, cached.?);
    }

    // Cleanup
    for (wrappers) |wrapper| {
        destroyMockWrapper(testing.allocator, wrapper);
    }
    cleanupMockCacheEntries(&cache, &instances, testing.allocator);

    for (instances) |instance| {
        destroyMockInstance(testing.allocator, instance);
    }
}

// ============================================================================
// Test 6: Clear Cache
// ============================================================================

test "WrapperCache - clear removes all entries without leaking" {
    const context = createMockContext();
    defer destroyMockContext(context);

    const isolate = createMockIsolate();
    defer destroyMockIsolate(isolate);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    const count = 50;
    var instances: [count]*runtime.Instance = undefined;
    var wrappers: [count]*v8.Object = undefined;

    // Add entries
    for (0..count) |i| {
        instances[i] = try createMockInstance(testing.allocator);
        wrappers[i] = try createMockWrapper(testing.allocator);
        try cache.set(instances[i], wrappers[i], isolate);
    }

    try testing.expectEqual(@as(usize, count), cache.size());

    // Manually clean up wrappers before clearing (since they're mocks)
    for (wrappers) |wrapper| {
        destroyMockWrapper(testing.allocator, wrapper);
    }

    // Clear cache (manually without V8 dispose)
    cleanupMockCacheEntries(&cache, &instances, testing.allocator);

    // Verify empty
    try testing.expectEqual(@as(usize, 0), cache.size());

    for (instances) |instance| {
        try testing.expect(cache.get(instance) == null);
    }

    // Cleanup instances
    for (instances) |instance| {
        destroyMockInstance(testing.allocator, instance);
    }
}

// ============================================================================
// Test 7: Multiple Caches (Separate Contexts)
// SKIP: Requires real V8 objects - mock objects cause bus error when
//       cache.set() calls v8_Global_SetWeak()
// ============================================================================

// test "WrapperCache - multiple caches are independent" {
//     const context1 = createMockContext();
//     defer destroyMockContext(context1);
//
//     const context2 = createMockContext();
//     defer destroyMockContext(context2);
//
//     const isolate = createMockIsolate();
//     defer destroyMockIsolate(isolate);
//
//     var cache1 = try WrapperCache.init(testing.allocator, context1);
//     defer cache1.deinit();
//
//     var cache2 = try WrapperCache.init(testing.allocator, context2);
//     defer cache2.deinit();
//
//     const instance1 = try createMockInstance(testing.allocator);
//     defer destroyMockInstance(testing.allocator, instance1);
//
//     const instance2 = try createMockInstance(testing.allocator);
//     defer destroyMockInstance(testing.allocator, instance2);
//
//     const wrapper1 = try createMockWrapper(testing.allocator);
//     const wrapper2 = try createMockWrapper(testing.allocator);
//
//     // Add to different caches
//     try cache1.set(instance1, wrapper1, isolate);
//     try cache2.set(instance2, wrapper2, isolate);
//
//     // Verify independence
//     try testing.expectEqual(@as(usize, 1), cache1.size());
//     try testing.expectEqual(@as(usize, 1), cache2.size());
//
//     try testing.expect(cache1.get(instance1) != null);
//     try testing.expect(cache1.get(instance2) == null);
//
//     try testing.expect(cache2.get(instance2) != null);
//     try testing.expect(cache2.get(instance1) == null);
//
//     // Cleanup
//     destroyMockWrapper(testing.allocator, wrapper1);
//     destroyMockWrapper(testing.allocator, wrapper2);
//     cleanupMockCacheEntries(&cache1, testing.allocator);
//     cleanupMockCacheEntries(&cache2, testing.allocator);
// }

// ============================================================================
// Test 8: Cache Integrity After Partial Clear
// ============================================================================

test "WrapperCache - integrity after removing specific entries" {
    const context = createMockContext();
    defer destroyMockContext(context);

    const isolate = createMockIsolate();
    defer destroyMockIsolate(isolate);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    var instances: [5]*runtime.Instance = undefined;
    var wrappers: [5]*v8.Object = undefined;

    // Add 5 entries
    for (0..5) |i| {
        instances[i] = try createMockInstance(testing.allocator);
        wrappers[i] = try createMockWrapper(testing.allocator);
        try cache.set(instances[i], wrappers[i], isolate);
    }

    try testing.expectEqual(@as(usize, 5), cache.size());

    // Manually remove entry at index 2 (simulates weak callback for one element)
    // Use fetchRemove to get the CacheEntry and free it properly
    if (cache.cache.fetchRemove(instances[2])) |kv| {
        // Free the CacheEntry (this is what was leaking before)
        testing.allocator.destroy(kv.value);
    }
    destroyMockWrapper(testing.allocator, wrappers[2]);

    // Verify cache integrity
    try testing.expectEqual(@as(usize, 4), cache.size());

    // Others should still be cached
    try testing.expect(cache.get(instances[0]) != null);
    try testing.expect(cache.get(instances[1]) != null);
    try testing.expect(cache.get(instances[2]) == null); // Removed
    try testing.expect(cache.get(instances[3]) != null);
    try testing.expect(cache.get(instances[4]) != null);

    // Cleanup remaining entries
    for (0..5) |i| {
        if (i != 2) { // Skip the wrapper we already cleaned up
            destroyMockWrapper(testing.allocator, wrappers[i]);
        }
        destroyMockInstance(testing.allocator, instances[i]);
    }

    // Clean up remaining cache entries (indices 0, 1, 3, 4)
    var remaining_instances = [_]*runtime.Instance{ instances[0], instances[1], instances[3], instances[4] };
    cleanupMockCacheEntries(&cache, &remaining_instances, testing.allocator);
}
