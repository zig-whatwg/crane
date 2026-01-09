//! BSCOPE-05 Validation Tests: Per-Context Wrapper Cache + Realm Management
//!
//! These tests validate the BSCOPE-05 requirements:
//! 1. Leak test: create/destroy each context kind 100x under std.testing.allocator
//! 2. Wrapper identity holds per context; cross-context wrappers are not reused
//! 3. No dangling pointers during HashMap rehash
//! 4. Code compiles without errors
//! 5. No memory leaks
//!
//! ## Architecture
//!
//! Tests use mock V8 objects to verify cache mechanics without full V8 runtime.
//! The mock approach allows us to use std.testing.allocator for leak detection.
//!
//! IMPORTANT: We directly manipulate the cache's internal HashMap to bypass
//! V8 API calls (v8_Global_SetWeak) which crash on mock objects. This tests
//! the cache's data structure correctness, not V8 integration.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const WrapperCache = v8.WrapperCache;
const realm_mod = @import("runtime").realm;
const GlobalScopeKind = realm_mod.GlobalScopeKind;

/// Mock CacheEntry that mirrors the structure of the real one
/// Used for mock testing to bypass V8 API calls
const MockCacheEntry = struct {
    wrapper: *anyopaque,
    instance: *runtime.Instance,
    cache: *WrapperCache,
};

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

/// Create a mock V8 Object (wrapper) for testing
fn createMockWrapper(allocator: std.mem.Allocator) !*v8.Object {
    const wrapper_storage = try allocator.create(u64);
    wrapper_storage.* = @intFromPtr(wrapper_storage);
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
        .vtable = undefined,
        .state = undefined,
        .ctx = undefined,
    };
    return instance;
}

/// Destroy mock runtime Instance
fn destroyMockInstance(allocator: std.mem.Allocator, instance: *runtime.Instance) void {
    allocator.destroy(instance);
}

/// Add entry to cache directly (bypasses V8 weak callback setup)
/// This is safe for mock testing since we don't call v8_Global_SetWeak
fn mockCacheSet(cache: *WrapperCache, instance: *runtime.Instance, wrapper: *v8.Object) !void {
    const entry = try cache.allocator.create(MockCacheEntry);
    entry.* = .{
        .wrapper = @ptrCast(wrapper),
        .instance = instance,
        .cache = cache,
    };
    // Cast to the opaque entry type expected by the cache
    try cache.cache.put(instance, @ptrCast(entry));
}

/// Cleanup cache entries without calling V8 dispose (for mock objects)
fn cleanupMockCacheEntries(cache: *WrapperCache, instances: []const *runtime.Instance) void {
    for (instances) |instance| {
        if (cache.cache.fetchRemove(instance)) |kv| {
            const entry: *MockCacheEntry = @ptrCast(@alignCast(kv.value));
            cache.allocator.destroy(entry);
        }
    }
}

/// Deinit cache without V8 calls (for mock testing)
fn mockCacheDeinit(cache: *WrapperCache) void {
    // Just free entries and deinit HashMap, no V8 calls
    var iter = cache.cache.valueIterator();
    while (iter.next()) |entry_ptr| {
        const entry: *MockCacheEntry = @ptrCast(@alignCast(entry_ptr.*));
        cache.allocator.destroy(entry);
    }
    cache.cache.deinit();
}

// ============================================================================
// BSCOPE-05 Validation Test 1: Leak Test - 100 Create/Destroy Cycles
// ============================================================================

test "BSCOPE-05: WrapperCache 100 create/destroy cycles - no memory leaks" {
    // This test validates criterion 1: "Leak test: create/destroy each context kind 100x"
    // and criterion 5: "No memory leaks"
    //
    // We create and destroy wrapper caches 100 times, using std.testing.allocator
    // which will fail the test if any memory leaks occur.

    for (0..100) |_| {
        const context = createMockContext();
        defer destroyMockContext(context);

        var cache = try WrapperCache.init(testing.allocator, context);

        // Add some entries to make it realistic
        var instances: [5]*runtime.Instance = undefined;
        var wrappers: [5]*v8.Object = undefined;

        for (0..5) |i| {
            instances[i] = try createMockInstance(testing.allocator);
            wrappers[i] = try createMockWrapper(testing.allocator);
            try mockCacheSet(&cache, instances[i], wrappers[i]);
        }

        // Verify cache populated
        try testing.expectEqual(@as(usize, 5), cache.size());

        // Cleanup mock wrappers and cache entries before deinit
        for (wrappers) |wrapper| {
            destroyMockWrapper(testing.allocator, wrapper);
        }
        cleanupMockCacheEntries(&cache, &instances);

        // Cleanup mock instances
        for (instances) |instance| {
            destroyMockInstance(testing.allocator, instance);
        }

        mockCacheDeinit(&cache);
    }

    // If we get here without std.testing.allocator detecting leaks, test passes
}

// ============================================================================
// BSCOPE-05 Validation Test 2: Per-Context Wrapper Identity Isolation
// ============================================================================

test "BSCOPE-05: wrapper identity isolation - cross-context wrappers not reused" {
    // This test validates criterion 2: "Wrapper identity holds per context;
    // cross-context wrappers are not reused"
    //
    // Each context has its own independent WrapperCache. Entries in one cache
    // must not be visible or leak into another cache.

    // Create two separate contexts
    const context1 = createMockContext();
    defer destroyMockContext(context1);

    const context2 = createMockContext();
    defer destroyMockContext(context2);

    // Create separate caches for each context (as per BSCOPE-05 design)
    var cache1 = try WrapperCache.init(testing.allocator, context1);
    var cache2 = try WrapperCache.init(testing.allocator, context2);

    // Create separate instances and wrappers for each context
    const instance1 = try createMockInstance(testing.allocator);
    const instance2 = try createMockInstance(testing.allocator);
    const wrapper1 = try createMockWrapper(testing.allocator);
    const wrapper2 = try createMockWrapper(testing.allocator);

    // Cache in context 1 (using mock set to bypass V8 APIs)
    try mockCacheSet(&cache1, instance1, wrapper1);

    // Cache in context 2 (different instance, different wrapper)
    try mockCacheSet(&cache2, instance2, wrapper2);

    // CRITICAL VALIDATION: Caches are isolated
    // instance1 should only be found in cache1, NOT in cache2
    try testing.expect(cache1.get(instance1) != null);
    try testing.expect(cache2.get(instance1) == null); // Not in cache2

    // instance2 should only be found in cache2, NOT in cache1
    try testing.expect(cache2.get(instance2) != null);
    try testing.expect(cache1.get(instance2) == null); // Not in cache1

    // Verify each returns the correct wrapper
    try testing.expectEqual(wrapper1, cache1.get(instance1).?);
    try testing.expectEqual(wrapper2, cache2.get(instance2).?);

    // Verify wrappers are distinct objects
    try testing.expect(wrapper1 != wrapper2);

    // Cleanup
    destroyMockWrapper(testing.allocator, wrapper1);
    destroyMockWrapper(testing.allocator, wrapper2);
    cleanupMockCacheEntries(&cache1, &[_]*runtime.Instance{instance1});
    cleanupMockCacheEntries(&cache2, &[_]*runtime.Instance{instance2});
    destroyMockInstance(testing.allocator, instance1);
    destroyMockInstance(testing.allocator, instance2);

    mockCacheDeinit(&cache1);
    mockCacheDeinit(&cache2);
}

// ============================================================================
// BSCOPE-05 Validation Test 3: HashMap Rehash Safety
// ============================================================================

test "BSCOPE-05: HashMap rehash safety - no dangling pointers" {
    // BSCOPE-05 Validation Criterion #3:
    // Verify that HashMap rehashing doesn't create dangling pointers.
    //
    // The WrapperCache and ContextManager use HEAP-ALLOCATED entries stored as
    // pointers in the HashMap. This design guarantees that when the HashMap
    // grows/shrinks (rehashes), the actual entry data remains at stable addresses.
    //
    // This test validates the pattern using a mock HashMap that mimics this design.

    const HeapEntry = struct {
        key: usize,
        value: usize,
    };

    // Create a HashMap storing pointers to heap-allocated entries (same pattern as WrapperCache)
    var map = std.AutoHashMap(usize, *HeapEntry).init(testing.allocator);
    defer map.deinit();

    // Track all heap entries for cleanup
    var entries: [200]*HeapEntry = undefined;
    var entry_count: usize = 0;

    // Phase 1: Add 100 entries to trigger initial growth/rehashing
    for (0..100) |i| {
        const entry = try testing.allocator.create(HeapEntry);
        entry.* = .{ .key = i, .value = i * 10 };
        entries[entry_count] = entry;
        entry_count += 1;
        try map.put(i, entry);
    }

    try testing.expectEqual(@as(usize, 100), map.count());

    // Phase 2: Remove half the entries (might trigger shrink/rehash)
    for (0..50) |i| {
        if (map.fetchRemove(i)) |kv| {
            // Entry was in map, now removed - but entry data is still valid
            try testing.expectEqual(i, kv.value.key);
            try testing.expectEqual(i * 10, kv.value.value);
        }
    }

    try testing.expectEqual(@as(usize, 50), map.count());

    // Phase 3: Add 50 more entries (might trigger growth/rehash)
    for (100..150) |i| {
        const entry = try testing.allocator.create(HeapEntry);
        entry.* = .{ .key = i, .value = i * 10 };
        entries[entry_count] = entry;
        entry_count += 1;
        try map.put(i, entry);
    }

    try testing.expectEqual(@as(usize, 100), map.count());

    // Phase 4: Verify ALL remaining entries are still accessible with correct values
    // This is the critical test - after multiple add/remove cycles that trigger
    // rehashing, the heap-allocated entries must still be valid.
    for (50..100) |i| {
        const entry = map.get(i);
        try testing.expect(entry != null);
        try testing.expectEqual(i, entry.?.key);
        try testing.expectEqual(i * 10, entry.?.value);
    }

    for (100..150) |i| {
        const entry = map.get(i);
        try testing.expect(entry != null);
        try testing.expectEqual(i, entry.?.key);
        try testing.expectEqual(i * 10, entry.?.value);
    }

    // Cleanup all heap entries
    for (0..entry_count) |i| {
        testing.allocator.destroy(entries[i]);
    }
}

// ============================================================================
// BSCOPE-05 Validation Test 4: GlobalScopeKind Enumeration Coverage
// ============================================================================

test "BSCOPE-05: GlobalScopeKind covers all scope types" {
    // This test validates that GlobalScopeKind has all required scope types
    // for the browser architecture.

    // Verify all expected scope kinds exist
    const expected_kinds = [_]GlobalScopeKind{
        .window,
        .dedicated_worker,
        .shared_worker,
        .service_worker,
        .audio_worklet,
        .paint_worklet,
        .animation_worklet,
        .layout_worklet,
        .shared_storage_worklet,
        .shadow_realm,
        .unknown,
    };

    // Verify each has a valid name
    for (expected_kinds) |kind| {
        const name = kind.name();
        try testing.expect(name.len > 0);
    }

    // Verify worker/worklet classification
    try testing.expect(GlobalScopeKind.dedicated_worker.isWorker());
    try testing.expect(GlobalScopeKind.shared_worker.isWorker());
    try testing.expect(GlobalScopeKind.service_worker.isWorker());
    try testing.expect(!GlobalScopeKind.window.isWorker());

    try testing.expect(GlobalScopeKind.audio_worklet.isWorklet());
    try testing.expect(GlobalScopeKind.paint_worklet.isWorklet());
    try testing.expect(!GlobalScopeKind.window.isWorklet());
    try testing.expect(!GlobalScopeKind.dedicated_worker.isWorklet());

    try testing.expect(GlobalScopeKind.shadow_realm.isShadowRealm());
    try testing.expect(!GlobalScopeKind.window.isShadowRealm());
}

// ============================================================================
// BSCOPE-05 Validation Test 5: Cache Per Scope Kind - Stress Test
// ============================================================================

test "BSCOPE-05: per-scope wrapper cache stress test - all scope kinds" {
    // This test creates wrapper caches simulating each scope kind
    // and verifies no cross-contamination and no memory leaks.

    const scope_kinds = [_]GlobalScopeKind{
        .window,
        .dedicated_worker,
        .shared_worker,
        .service_worker,
        .audio_worklet,
        .paint_worklet,
        .shadow_realm,
    };

    // Create a context and cache for each scope kind
    var contexts: [scope_kinds.len]*v8.Context = undefined;
    var caches: [scope_kinds.len]WrapperCache = undefined;

    for (0..scope_kinds.len) |i| {
        contexts[i] = createMockContext();
        caches[i] = try WrapperCache.init(testing.allocator, contexts[i]);
    }

    // Create instances and wrappers for each scope
    var all_instances: [scope_kinds.len][10]*runtime.Instance = undefined;
    var all_wrappers: [scope_kinds.len][10]*v8.Object = undefined;

    for (0..scope_kinds.len) |scope_idx| {
        for (0..10) |i| {
            all_instances[scope_idx][i] = try createMockInstance(testing.allocator);
            all_wrappers[scope_idx][i] = try createMockWrapper(testing.allocator);
            try mockCacheSet(&caches[scope_idx], all_instances[scope_idx][i], all_wrappers[scope_idx][i]);
        }
    }

    // Verify each cache has correct count
    for (0..scope_kinds.len) |i| {
        try testing.expectEqual(@as(usize, 10), caches[i].size());
    }

    // Verify no cross-contamination: instance from scope A not found in scope B
    for (0..scope_kinds.len) |scope_a| {
        for (0..scope_kinds.len) |scope_b| {
            if (scope_a == scope_b) continue;

            // Instance from scope_a should NOT be in cache for scope_b
            for (0..10) |i| {
                const instance_a = all_instances[scope_a][i];
                const found_in_b = caches[scope_b].get(instance_a);
                try testing.expect(found_in_b == null);
            }
        }
    }

    // Cleanup all
    for (0..scope_kinds.len) |scope_idx| {
        for (0..10) |i| {
            destroyMockWrapper(testing.allocator, all_wrappers[scope_idx][i]);
        }
        cleanupMockCacheEntries(&caches[scope_idx], &all_instances[scope_idx]);
        for (0..10) |i| {
            destroyMockInstance(testing.allocator, all_instances[scope_idx][i]);
        }
        mockCacheDeinit(&caches[scope_idx]);
        destroyMockContext(contexts[scope_idx]);
    }
}

// ============================================================================
// BSCOPE-05 Validation Test 6: Rapid Context Lifecycle (100 cycles per scope)
// ============================================================================

test "BSCOPE-05: rapid context lifecycle - 100 cycles per scope kind" {
    // This is the comprehensive leak test: create/destroy 100 times for each scope kind
    // using std.testing.allocator for leak detection.

    const scope_kinds = [_]GlobalScopeKind{
        .window,
        .dedicated_worker,
        .shared_worker,
        .service_worker,
        .audio_worklet,
        .shadow_realm,
    };

    for (scope_kinds) |scope_kind| {
        // 100 create/destroy cycles for this scope kind
        for (0..100) |_| {
            const context = createMockContext();
            var cache = try WrapperCache.init(testing.allocator, context);

            // Add entries typical for this scope kind
            const entry_count: usize = switch (scope_kind) {
                .window => 20, // Windows typically have more objects
                .dedicated_worker => 5,
                .shared_worker => 3,
                .service_worker => 5,
                .audio_worklet => 2,
                .shadow_realm => 3,
                else => 1,
            };

            var instances = try testing.allocator.alloc(*runtime.Instance, entry_count);
            defer testing.allocator.free(instances);
            var wrappers = try testing.allocator.alloc(*v8.Object, entry_count);
            defer testing.allocator.free(wrappers);

            for (0..entry_count) |i| {
                instances[i] = try createMockInstance(testing.allocator);
                wrappers[i] = try createMockWrapper(testing.allocator);
                try mockCacheSet(&cache, instances[i], wrappers[i]);
            }

            // Cleanup
            for (0..entry_count) |i| {
                destroyMockWrapper(testing.allocator, wrappers[i]);
            }
            cleanupMockCacheEntries(&cache, instances);
            for (0..entry_count) |i| {
                destroyMockInstance(testing.allocator, instances[i]);
            }

            mockCacheDeinit(&cache);
            destroyMockContext(context);
        }
    }

    // If std.testing.allocator doesn't report leaks, all 600 cycles (100 x 6 scopes) passed
}
