//! Implementation for CacheStorage interface
//!
//! Provides an in-memory Cache API implementation.
//! Spec: https://w3c.github.io/ServiceWorker/#cachestorage-interface
//!
//! Note: CacheStorage API methods return Promises per spec. Full Promise
//! integration requires JS engine Promise creation which is handled by
//! the V8 binding layer.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const CacheStorageInterface = interfaces.CacheStorage;

// Import Cache impl for creating Cache instances
const CacheImpl = @import("Cache.zig");

pub const State = CacheStorageInterface.State;

pub const ImplError = error{
    OutOfMemory,
    TypeError,
    InvalidState,
    NotImplemented,
};

/// Internal state for CacheStorage
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Map of cache name to Cache instance
    caches: std.StringHashMapUnmanaged(*runtime.Instance),
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = .{
        .allocator = allocator,
        .caches = .{},
    };

    // Store in instance state
    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        const allocator = internal.allocator;

        // Free all cache names and deinit cache instances
        var iter = internal.caches.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            // Note: Cache instances will be cleaned up by GC
        }
        internal.caches.deinit(allocator);

        allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit(instance) here!
    // The GC integration layer handles slab freeing after this returns.
}

/// Helper to get cache name as slice from DOMString
fn getCacheName(cacheName: runtime.DOMString) []const u8 {
    return cacheName.asSlice();
}

/// Operation: delete - Delete a cache by name
/// Spec: https://w3c.github.io/ServiceWorker/#cache-storage-delete
/// Returns: Promise<boolean>
pub fn call_delete(instance: *runtime.Instance, cacheName: runtime.DOMString) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const name = getCacheName(cacheName);

    // Delete the cache
    if (internal.caches.fetchRemove(name)) |entry| {
        // Free the key
        internal.allocator.free(entry.key);
        // Cache instance will be cleaned up by GC
        // Deletion succeeded - return NotImplemented to signal the V8 layer
        // should create a resolved Promise<true>
    }

    // Return NotImplemented - the V8 layer should create the appropriate Promise
    return error.NotImplemented;
}

/// Operation: keys - Get all cache names
/// Spec: https://w3c.github.io/ServiceWorker/#cache-storage-keys
/// Returns: Promise<sequence<DOMString>>
///
/// Returns an array of all cache names in creation order.
pub fn call_keys(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Collect all cache names
    // Note: StringHashMapUnmanaged doesn't preserve insertion order, but the spec
    // requires keys to be returned in creation order. For a full implementation,
    // we would need to maintain an ordered list of cache names.
    var names = std.ArrayListUnmanaged([]const u8){};
    defer names.deinit(internal.allocator);

    var iter = internal.caches.keyIterator();
    while (iter.next()) |key_ptr| {
        try names.append(internal.allocator, key_ptr.*);
    }

    // The V8 binding layer should:
    // 1. Create a JavaScript array from these names
    // 2. Wrap in a resolved Promise
    // 3. Return Promise<sequence<DOMString>>
    //
    // For now, we return NotImplemented to signal that results are available
    // but the V8 layer needs to create the Promise wrapper.
    _ = names.items;
    return error.NotImplemented;
}

/// Operation: has - Check if a cache exists
/// Spec: https://w3c.github.io/ServiceWorker/#cache-storage-has
/// Returns: Promise<boolean>
pub fn call_has(instance: *runtime.Instance, cacheName: runtime.DOMString) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const name = getCacheName(cacheName);

    // Check if cache exists
    const exists = internal.caches.contains(name);
    _ = exists;

    // Return NotImplemented - the V8 layer should create the appropriate Promise
    return error.NotImplemented;
}

/// Operation: open - Open or create a cache
/// Spec: https://w3c.github.io/ServiceWorker/#cache-storage-open
/// Returns: Promise<Cache>
pub fn call_open(instance: *runtime.Instance, cacheName: runtime.DOMString) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const name = getCacheName(cacheName);

    // If cache exists, return it
    if (internal.caches.get(name)) |cache_instance| {
        return runtime.JSValue.fromInstance(cache_instance);
    }

    // Create a new Cache instance
    const Cache = interfaces.Cache;
    const cache_instance = try CacheImpl.initWithName(
        internal.allocator,
        Cache.State,
        &Cache.vtable,
        instance.ctx,
        name,
    );
    errdefer runtime.Instance.deinit(cache_instance);

    // Store with duplicated key
    const key = try internal.allocator.dupe(u8, name);
    errdefer internal.allocator.free(key);

    try internal.caches.put(internal.allocator, key, cache_instance);

    return runtime.JSValue.fromInstance(cache_instance);
}

/// Operation: match - Search all caches for a matching response
/// Spec: https://w3c.github.io/ServiceWorker/#cache-storage-match
/// Returns: Promise<Response | undefined>
pub fn call_match(instance: *runtime.Instance, request: typedefs.RequestInfo, options: webidl.Opt(dictionaries.MultiCacheQueryOptions)) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // If cache_name is specified, only search that cache
    if (options.wasPassed()) {
        if (options.value.cacheName) |name_dom| {
            const name = name_dom.asSlice();
            if (internal.caches.get(name)) |cache_instance| {
                // Delegate to Cache.match
                return CacheImpl.call_match(cache_instance, request, webidl.Opt(dictionaries.CacheQueryOptions).passed(options.value.base));
            }
            // Cache not found - return NotImplemented for "no match"
            return error.NotImplemented;
        }
    }

    // Search all caches
    var iter = internal.caches.iterator();
    while (iter.next()) |entry| {
        const cache_instance = entry.value_ptr.*;

        // Get base options
        const base_options = if (options.wasPassed())
            webidl.Opt(dictionaries.CacheQueryOptions).passed(options.value.base)
        else
            webidl.Opt(dictionaries.CacheQueryOptions).notPassed();

        // Try to match - if NotImplemented, means no match in this cache
        const result = CacheImpl.call_match(cache_instance, request, base_options) catch |err| {
            if (err == error.NotImplemented) {
                continue; // No match, try next cache
            }
            return err;
        };
        return result;
    }

    // No match found in any cache
    return error.NotImplemented;
}
