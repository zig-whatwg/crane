//! V8 Wrapper Identity Cache
//!
//! Per-context cache that maintains 1:1 mapping between Zig instances and V8 wrappers.
//! Solves the wrapper identity problem where multiple calls to querySelector
//! return different V8 wrappers for the same DOM element.
//!
//! ## Problem Solved
//!
//! **Before** (without cache):
//! ```javascript
//! const h1 = document.querySelector("header");
//! const h2 = document.querySelector("header");
//! console.log(h1 === h2); // false ❌ Different V8 wrappers!
//! ```
//!
//! **After** (with cache):
//! ```javascript
//! const h1 = document.querySelector("header");
//! const h2 = document.querySelector("header");
//! console.log(h1 === h2); // true ✅ Same V8 wrapper cached!
//! ```
//!
//! ## Architecture
//!
//! - **Key**: `*runtime.Instance` (Zig DOM instance pointer)
//! - **Value**: `*anyopaque` (V8 Global<Object>* handle - persistent across scopes)
//! - **Lifetime**: Weak callbacks automatically remove entries when V8 GC collects wrappers
//! - **Scope**: Per-context (each V8 Context has its own cache)
//!
//! ## Usage
//!
//! During V8 Context initialization:
//! ```zig
//! var cache = try WrapperCache.init(allocator, context);
//! defer cache.deinit();
//! ```
//!
//! When wrapping an instance (in template_registry.wrapInstanceAsV8Object):
//! ```zig
//! // Check cache first
//! if (cache.get(instance)) |cached_wrapper| {
//!     return cached_wrapper; // Return existing wrapper
//! }
//!
//! // Create new wrapper
//! const v8_obj = createNewWrapper(instance, template, context);
//!
//! // Cache it with weak callback for GC cleanup
//! try cache.set(instance, v8_obj, isolate);
//! ```
//!
//! ## GC Integration
//!
//! Weak callbacks automatically clean up cache entries when V8 garbage collects wrappers:
//! 1. V8 GC determines wrapper is no longer reachable
//! 2. Weak callback fires with CacheEntry pointer
//! 3. Callback removes entry from HashMap
//! 4. Callback frees Global<Object>* handle
//!
//! ## Thread Safety
//!
//! NOT thread-safe. Each V8 Context is single-threaded, so the cache is also single-threaded.
//! Multiple contexts can have separate caches on different threads.

const std = @import("std");
const v8 = @import("ffi.zig");
const runtime = @import("runtime");

/// Cache entry stored in the HashMap
///
/// Contains both the V8 wrapper handle and backpointer to the cache for cleanup.
const CacheEntry = struct {
    /// V8 Global<Object>* handle (persistent wrapper)
    wrapper: *anyopaque,

    /// Zig instance pointer (key for HashMap lookup during cleanup)
    instance: *runtime.Instance,

    /// Backpointer to cache (needed for removal during weak callback)
    cache: *WrapperCache,
};

/// Weak callback for GC cleanup
///
/// Called by V8 when the wrapper object is garbage collected.
/// This is the critical GC integration point that ensures Zig memory
/// is properly freed when JavaScript objects are collected.
///
/// The cleanup sequence is:
/// 1. Call gc_integration.onObjectFreed() to invoke type-specific deinit
///    (e.g., Response.deinit frees headers, body, URL list)
/// 2. Remove entry from cache HashMap
/// 3. Dispose the V8 Global<Object>* handle
/// 4. Free the CacheEntry
fn weakCallback(data: ?*anyopaque, length_in_bytes: usize) callconv(.c) void {
    _ = length_in_bytes;

    if (data) |entry_ptr| {
        const entry: *CacheEntry = @ptrCast(@alignCast(entry_ptr));

        // Step 1: Clean up the Zig instance via GC integration
        // This calls the type's deinit function (e.g., Response.deinit)
        // which frees all owned resources (headers, body, URL list, etc.)
        // and returns the Instance handle to the SlabAllocator
        runtime.gc.onObjectFreed(entry.instance);

        // Step 2: Remove from cache HashMap
        _ = entry.cache.cache.remove(entry.instance);

        // Step 3: Dispose the Global<Object>* handle
        v8.v8_Object_Dispose(@ptrCast(entry.wrapper));

        // Step 4: Free the CacheEntry
        entry.cache.allocator.destroy(entry);
    }
}

/// V8 Wrapper Identity Cache
///
/// Per-context cache maintaining 1:1 mapping between Zig instances and V8 wrappers.
pub const WrapperCache = struct {
    /// HashMap: *runtime.Instance → CacheEntry
    cache: std.AutoHashMap(*runtime.Instance, *CacheEntry),

    /// Allocator for cache entries
    allocator: std.mem.Allocator,

    /// V8 Context (unused currently, kept for future extensions)
    context: *v8.Context,

    const Self = @This();

    /// Initialize a new wrapper cache
    ///
    /// Creates an empty HashMap ready to cache wrappers.
    ///
    /// ## Parameters
    /// - allocator: Memory allocator for cache entries
    /// - context: V8 Context this cache belongs to
    ///
    /// ## Returns
    /// Initialized WrapperCache
    pub fn init(allocator: std.mem.Allocator, context: *v8.Context) !Self {
        return .{
            .cache = std.AutoHashMap(*runtime.Instance, *CacheEntry).init(allocator),
            .allocator = allocator,
            .context = context,
        };
    }

    /// Clean up cache resources
    ///
    /// Disposes all cached Global handles and frees the HashMap.
    /// Should be called when the V8 Context is destroyed.
    pub fn deinit(self: *Self) void {
        // Dispose all cached Global handles
        var iter = self.cache.valueIterator();
        while (iter.next()) |entry_ptr| {
            const entry = entry_ptr.*;

            // Dispose the Global<Object>* handle
            v8.v8_Object_Dispose(@ptrCast(entry.wrapper));

            // Free the CacheEntry
            self.allocator.destroy(entry);
        }

        self.cache.deinit();
    }

    /// Get cached wrapper for an instance
    ///
    /// ## Parameters
    /// - instance: The Zig instance to look up
    ///
    /// ## Returns
    /// V8 Object wrapper if cached, null otherwise
    pub fn get(self: *Self, instance: *runtime.Instance) ?*v8.Object {
        if (self.cache.get(instance)) |entry| {
            return @ptrCast(entry.wrapper);
        }
        return null;
    }

    /// Cache a wrapper for an instance with weak callback
    ///
    /// Stores the wrapper in the cache and sets up a weak callback for GC cleanup.
    ///
    /// ## Parameters
    /// - instance: The Zig instance (cache key)
    /// - wrapper: The V8 Object wrapper (Global<Object>* handle)
    /// - isolate: V8 isolate (for setting weak callback)
    ///
    /// ## Errors
    /// - OutOfMemory: If allocation fails
    pub fn set(
        self: *Self,
        instance: *runtime.Instance,
        wrapper: *v8.Object,
        isolate: *v8.Isolate,
    ) !void {
        _ = isolate; // Will be used for weak callback in next commit

        // Allocate CacheEntry
        const entry = try self.allocator.create(CacheEntry);
        errdefer self.allocator.destroy(entry);

        entry.* = .{
            .wrapper = @ptrCast(wrapper),
            .instance = instance,
            .cache = self,
        };

        // Store in HashMap
        try self.cache.put(instance, entry);

        // Set weak callback for GC cleanup
        v8.v8_Global_SetWeak(
            @ptrCast(wrapper),
            @ptrCast(entry),
            weakCallback,
        );
    }

    /// Clear the entire cache
    ///
    /// Disposes all cached wrappers and clears the HashMap.
    /// Useful for testing or explicit cache invalidation.
    pub fn clear(self: *Self) void {
        var iter = self.cache.valueIterator();
        while (iter.next()) |entry_ptr| {
            const entry = entry_ptr.*;

            // Dispose the Global<Object>* handle
            v8.v8_Object_Dispose(@ptrCast(entry.wrapper));

            // Free the CacheEntry
            self.allocator.destroy(entry);
        }

        self.cache.clearRetainingCapacity();
    }

    /// Remove a specific entry from the cache
    ///
    /// Removes the entry for the given instance, disposes the V8 handle,
    /// and frees the CacheEntry. Returns true if entry was found and removed.
    ///
    /// ## Parameters
    /// - instance: The Zig instance to remove from cache
    ///
    /// ## Returns
    /// true if entry was found and removed, false if not in cache
    pub fn remove(self: *Self, instance: *runtime.Instance) bool {
        if (self.cache.fetchRemove(instance)) |kv| {
            const entry = kv.value;

            // Dispose the Global<Object>* handle
            v8.v8_Object_Dispose(@ptrCast(entry.wrapper));

            // Free the CacheEntry
            self.allocator.destroy(entry);

            return true;
        }
        return false;
    }

    /// Get cache statistics
    ///
    /// Returns the number of cached wrappers.
    /// Useful for debugging and monitoring.
    pub fn size(self: *const Self) usize {
        return self.cache.count();
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "WrapperCache - init and deinit" {
    // Mock V8 Context (just a dummy pointer for testing)
    var dummy_context: u32 = 42;
    const context: *v8.Context = @ptrCast(&dummy_context);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    try testing.expectEqual(@as(usize, 0), cache.size());
}

test "WrapperCache - get returns null when empty" {
    var dummy_context: u32 = 42;
    const context: *v8.Context = @ptrCast(&dummy_context);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    // Mock instance
    var dummy_instance: runtime.Instance = undefined;

    const result = cache.get(&dummy_instance);
    try testing.expectEqual(@as(?*v8.Object, null), result);
}

test "WrapperCache - set and get basic operation" {
    var dummy_context: u32 = 42;
    const context: *v8.Context = @ptrCast(&dummy_context);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    // Mock instance and wrapper
    var dummy_instance: runtime.Instance = undefined;
    var dummy_wrapper: u64 = 0xDEADBEEF;
    const wrapper: *v8.Object = @ptrCast(&dummy_wrapper);

    // Mock isolate
    var dummy_isolate: u32 = 99;
    const isolate: *v8.Isolate = @ptrCast(&dummy_isolate);

    // NOTE: This test will fail when run with actual V8 because v8_Global_SetWeak
    // expects a real Global handle. This is a structural test only.
    // Actual integration testing requires V8 runtime.

    // Set wrapper in cache
    try cache.set(&dummy_instance, wrapper, isolate);

    // Get wrapper from cache
    const cached = cache.get(&dummy_instance);
    try testing.expect(cached != null);
    try testing.expectEqual(wrapper, cached.?);

    try testing.expectEqual(@as(usize, 1), cache.size());
}

test "WrapperCache - clear removes all entries" {
    var dummy_context: u32 = 42;
    const context: *v8.Context = @ptrCast(&dummy_context);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    // Mock instances and wrappers
    var instance1: runtime.Instance = undefined;
    var instance2: runtime.Instance = undefined;
    var wrapper1: u64 = 0xDEAD;
    var wrapper2: u64 = 0xBEEF;
    var dummy_isolate: u32 = 99;
    const isolate: *v8.Isolate = @ptrCast(&dummy_isolate);

    try cache.set(&instance1, @ptrCast(&wrapper1), isolate);
    try cache.set(&instance2, @ptrCast(&wrapper2), isolate);

    try testing.expectEqual(@as(usize, 2), cache.size());

    // Clear cache
    cache.clear();

    try testing.expectEqual(@as(usize, 0), cache.size());
    try testing.expectEqual(@as(?*v8.Object, null), cache.get(&instance1));
    try testing.expectEqual(@as(?*v8.Object, null), cache.get(&instance2));
}

test "WrapperCache - no memory leaks" {
    var dummy_context: u32 = 42;
    const context: *v8.Context = @ptrCast(&dummy_context);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    // Allocate multiple entries
    var instances: [10]runtime.Instance = undefined;
    var wrappers: [10]u64 = undefined;
    var dummy_isolate: u32 = 99;
    const isolate: *v8.Isolate = @ptrCast(&dummy_isolate);

    for (&instances, &wrappers) |*inst, *wrap| {
        wrap.* = 0xDEADBEEF;
        try cache.set(inst, @ptrCast(wrap), isolate);
    }

    try testing.expectEqual(@as(usize, 10), cache.size());

    // deinit() should clean up all entries without leaking
}

test "WrapperCache - remove specific entry" {
    var dummy_context: u32 = 42;
    const context: *v8.Context = @ptrCast(&dummy_context);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    // Mock instances and wrappers
    var instance1: runtime.Instance = undefined;
    var instance2: runtime.Instance = undefined;
    var instance3: runtime.Instance = undefined;
    var wrapper1: u64 = 0xDEAD;
    var wrapper2: u64 = 0xBEEF;
    var wrapper3: u64 = 0xCAFE;
    var dummy_isolate: u32 = 99;
    const isolate: *v8.Isolate = @ptrCast(&dummy_isolate);

    try cache.set(&instance1, @ptrCast(&wrapper1), isolate);
    try cache.set(&instance2, @ptrCast(&wrapper2), isolate);
    try cache.set(&instance3, @ptrCast(&wrapper3), isolate);

    try testing.expectEqual(@as(usize, 3), cache.size());

    // Remove middle entry
    const removed = cache.remove(&instance2);
    try testing.expect(removed);
    try testing.expectEqual(@as(usize, 2), cache.size());

    // Verify correct entries remain
    try testing.expect(cache.get(&instance1) != null);
    try testing.expectEqual(@as(?*v8.Object, null), cache.get(&instance2)); // Removed
    try testing.expect(cache.get(&instance3) != null);

    // Remove non-existent entry
    const removed_again = cache.remove(&instance2);
    try testing.expect(!removed_again);
    try testing.expectEqual(@as(usize, 2), cache.size());
}
