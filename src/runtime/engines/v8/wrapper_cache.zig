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

const log = std.log.scoped(.wrapper_cache);

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

    /// Set to true when the instance has been cleaned up externally
    /// (e.g., via Node.deinit). When true, deinit should NOT call
    /// onObjectFreed since the instance is already cleaned up.
    instance_already_cleaned: bool = false,

    /// True while the wrapper is held strongly (no weak arm): the node has a
    /// parent, or the document has a window. See installTreeHooks.
    strong: bool = false,

    /// Set to true when the cache is being destroyed. This allows pending
    /// weak callbacks to detect that they should skip cleanup because:
    /// 1. The cache is no longer valid
    /// 2. The instance pointer may have been reused by a new object
    /// When orphaned, callbacks should just dispose the wrapper and entry
    /// without calling onObjectFreed.
    is_orphaned: bool = false,

    /// VTable pointer captured when entry was created.
    /// Used to detect if instance address was reused for a different object.
    /// If the current instance's vtable differs from this, the address was
    /// reused and we should not call onObjectFreed.
    original_vtable: *const runtime.VTable,

    /// State pointer captured when entry was created.
    /// Used to detect if instance address was reused for the SAME type.
    /// Even if vtable matches, if state differs, it's a different instance.
    original_state: *anyopaque,

    /// Slab generation of `instance` when this entry was made. A stale entry -
    /// one whose instance was freed and its slot reissued before the weak
    /// callback ran - differs here even when vtable and state match.
    original_generation: u64,
};

/// Dispose an entry's V8 handle, first dropping any alias to it.
///
/// `NodeBase.bound_v8_wrapper` (set by template_registry.wrapInstanceAsV8Object)
/// stores the SAME `Global<Object>*` handle that the cache entry owns, so that
/// DOM nodes keep JavaScript `===` identity across contexts. Disposing the
/// handle without clearing that alias leaves a dangling pointer which the next
/// wrapInstanceAsV8Object call would happily return.
///
/// The pointer-equality guard matters: instance addresses are recycled by the
/// SlabAllocator, so the NodeBase reachable from `entry.instance` may already
/// belong to a different object. Only an exact match is ours to clear.
fn disposeEntryWrapper(entry: *CacheEntry) void {
    const instance_bridge = @import("dom").instance_bridge;

    if (instance_bridge.getNodeBase(@ptrCast(entry.instance))) |nodebase| {
        if (nodebase.bound_v8_wrapper == entry.wrapper) {
            nodebase.bound_v8_wrapper = null;
        }
    }

    v8.v8_Object_Dispose(@ptrCast(entry.wrapper));
}

/// Weak callback for GC cleanup
///
/// Called by V8 when the wrapper object is garbage collected.
/// This is the critical GC integration point that ensures Zig memory
/// is properly freed when JavaScript objects are collected.
///
/// The cleanup sequence is:
/// 1. Check if context teardown is in progress (skip if so - coordinator handles it)
/// 2. Check if instance cleanup already started (via lifecycle flags)
/// 3. Call gc_integration.onObjectFreed() to invoke type-specific deinit
///    (e.g., Response.deinit frees headers, body, URL list)
/// 4. Remove entry from cache HashMap
/// 5. Dispose the V8 Global<Object>* handle
/// 6. Free the CacheEntry
/// True when the slab slot behind `entry.instance` no longer holds the
/// instance this entry was created for: freed (generation reads dead) or
/// reissued to a newcomer (a later generation). The vtable/state comparison
/// alone cannot see a same-type newcomer whose state block was recycled at
/// the same address - the case in which a stale callback's `Registry.remove`
/// evicted a live document's entry (AGENTS.md, "A stale weak callback's
/// `Registry.remove` evicts the LIVE entry at a recycled address").
fn slotReissued(entry: *const CacheEntry) bool {
    return entry.instance.vtable != entry.original_vtable or
        entry.instance.state != entry.original_state or
        runtime.SlabAllocator.generationOf(entry.instance) != entry.original_generation;
}

/// True while something other than V8 holds `instance`: a node with a parent
/// (its tree owns it) or a document with a default view (its browsing context
/// owns it). Read at callback time from the DOM's own parent pointer, which the
/// mutation algorithms keep current - and `slotReissued` has already
/// established that `instance` is the one this entry was made for. A stale
/// registry entry at a recycled address can only answer "owned" for something
/// that is not, which keeps an instance alive a little longer, never frees a
/// live one.
fn engineOwns(instance: *runtime.Instance) bool {
    if (isStreamsGraphObject(instance.vtable.name)) return true;
    if (isWindowOwned(instance)) return true;
    const NodeImpl = @import("impls").Node;
    if (NodeImpl.getInternalState(instance)) |node_internal| {
        if (node_internal.node_base) |node_base| {
            if (node_base.parent_node != null) return true;
        }
    }
    const DocumentImpl = @import("impls").Document;
    if (DocumentImpl.getInternalState(instance)) |doc_internal| {
        if (doc_internal.default_view != null) return true;
    }
    return false;
}

/// A window's Location and History: the Window holds each in its own state,
/// hands out that one instance on every `window.location` / `window.history`
/// ([SameObject]), and frees both in Window.deinit. Freeing one when its
/// wrapper was collected left the Window pointing at a freed slab slot, so
/// the next read returned whatever the slot held by then - an iframe's
/// `contentWindow.location.href` read undefined after a collection, and a
/// form submission navigating through it crashed. Blink keeps both alive
/// from the window: DOMWindow::Trace visits location_ and
/// LocalDOMWindow::Trace visits history_ (core/frame/dom_window.cc,
/// local_dom_window.cc).
fn isWindowOwned(instance: *runtime.Instance) bool {
    const impls = @import("impls");
    const name = instance.vtable.name;
    if (std.mem.eql(u8, name, "Location")) {
        const internal = impls.Location.getInternalState(instance) orelse return false;
        return internal.window != null;
    }
    if (std.mem.eql(u8, name, "History")) {
        const internal = impls.History.getInternal(instance) orelse return false;
        return internal.window != null;
    }
    return false;
}

/// Streams objects reach each other through Zig pointers V8 cannot see: a
/// stream's [[controller]] and [[writer]], a controller's [[stream]], and the
/// context of every pending promise reaction. Blink traces those slots
/// (third_party/blink/renderer/core/streams/, `Trace` on every class); with
/// Global handles there is nothing to trace, so collecting one wrapper frees
/// an instance another still points at. Their wrappers are held strongly and
/// the realm's teardown sweep frees them - memory for the realm's lifetime,
/// never a dangling [[controller]].
///
/// An allowlist, and only of the classes built on the `impls/streams_*.zig`
/// ownership rules: their teardown touches nothing but their own slots, so
/// the realm's sweep can free them in any order.
pub fn isStreamsGraphObject(name: []const u8) bool {
    const names = [_][]const u8{
        "WritableStream",
        "WritableStreamDefaultWriter",
        "WritableStreamDefaultController",
        "ReadableStream",
        "ReadableStreamDefaultReader",
        "ReadableStreamBYOBReader",
        "ReadableStreamDefaultController",
        "ReadableByteStreamController",
        "ReadableStreamBYOBRequest",
        "TransformStream",
        "TransformStreamDefaultController",
    };
    for (names) |n| {
        if (std.mem.eql(u8, name, n)) return true;
    }
    return false;
}

/// Which node wrappers V8 may collect. WebKit keeps a node's wrapper alive for
/// as long as the node's tree is (JSNodeOwner::isReachableFromOpaqueRoots: the
/// tree's root is the opaque root), and Blink traces the wrapper through the
/// node, so in both `el.expando` and `el === el` survive a collection while the
/// node is in a live tree. With Global handles that is: strong while the node
/// has a parent, weak once it is a root - the root's own reachability then
/// decides for the whole tree. The mutation algorithms run the insertion and
/// removing steps for every node of a moved subtree, but only the subtree's
/// root gains or loses a parent, so the predicate is read per node rather than
/// implied by which hook fired. Installed once, by the first WrapperCache.
var tree_hooks_installed = false;

fn installTreeHooks() void {
    if (tree_hooks_installed) return;
    tree_hooks_installed = true;
    const mutation = @import("dom").mutation;
    mutation.registerInsertionStepsCallback(onNodeInserted) catch {};
    mutation.registerRemovingStepsCallback(onNodeRemoved) catch {};
}

fn onNodeInserted(node: *@import("dom").NodeBase) void {
    syncStrength(node);
}

fn onNodeRemoved(node: *@import("dom").NodeBase, old_parent: ?*@import("dom").NodeBase) void {
    _ = old_parent;
    syncStrength(node);
}

fn syncStrength(node: *@import("dom").NodeBase) void {
    setStrong(instanceOfNode(node) orelse return, node.parent_node != null);
}

fn instanceOfNode(node: *@import("dom").NodeBase) ?*runtime.Instance {
    const instance_bridge = @import("dom").instance_bridge;
    const raw = instance_bridge.getInstance(node) orelse return null;
    return @ptrCast(@alignCast(raw));
}

/// A document becomes a window's document after it may already have been
/// wrapped (an iframe's document is handed out as contentDocument before its
/// context exists). From that moment the window aliases the wrapper - WebKit's
/// `document` is a strong reference - so it must be held, not just kept: a
/// document whose wrapper was collected under the window died in
/// LookupIterator::GetRootForNonJSReceiver on the next `document` access
/// (custom-elements/connected-callbacks.html, SIGTRAP).
pub fn holdStrong(instance: *runtime.Instance) void {
    setStrong(instance, true);
}

/// Hold or release `instance`'s wrapper, if its context's cache has one.
fn setStrong(instance: *runtime.Instance, strong: bool) void {
    const cache_storage = instance.ctx.getV8WrapperCacheStorage() orelse return;
    const cache: *WrapperCache = @ptrCast(@alignCast(cache_storage));
    if (cache.is_tearing_down) return;
    const entry = cache.cache.get(instance) orelse return;
    if (entry.strong == strong) return;
    if (strong) {
        v8.v8_Global_ClearWeak(@ptrCast(entry.wrapper));
    } else {
        v8.v8_Global_SetWeak(@ptrCast(entry.wrapper), @ptrCast(entry), weakCallback);
    }
    entry.strong = strong;
}

/// Every live WrapperCache on this thread - one per realm. A node has one
/// wrapper whatever realm reads it (its bound wrapper), but any other platform
/// object gets a wrapper in each realm's cache that wraps it: a span's
/// DOMStringMap read by its frame and by the frame's parent has two. The
/// instance must outlive all of them - Blink traces it from every world's
/// wrapper - so a cache frees an instance only when no other live cache still
/// wraps it. Freeing it on the first wrapper's death left the other realm's
/// wrapper, and the element's [SameObject] cache, on freed memory.
threadlocal var live_caches: std.ArrayListUnmanaged(*WrapperCache) = .empty;

/// Whether a live cache other than `except` holds a wrapper for this very
/// instance - same slot, same generation.
fn wrappedElsewhere(instance: *runtime.Instance, except: *const WrapperCache) bool {
    const generation = runtime.SlabAllocator.generationOf(instance);
    for (live_caches.items) |other| {
        if (other == except) continue;
        const entry = other.cache.get(instance) orelse continue;
        if (entry.original_generation == generation and entry.original_vtable == instance.vtable) return true;
    }
    return false;
}

fn weakCallback(data: ?*anyopaque, length_in_bytes: usize) callconv(.c) void {
    _ = length_in_bytes;

    if (data) |entry_ptr| {
        const entry: *CacheEntry = @ptrCast(@alignCast(entry_ptr));

        // CRITICAL: Check if entry is orphaned FIRST, before any cache access.
        // An orphaned entry means the cache was destroyed (via deinitWithoutCallbacks).
        // In this case:
        // 1. The cache pointer (entry.cache) may be invalid/freed
        // 2. The instance pointer (entry.instance) may have been reused for a new object
        // 3. We should NOT call onObjectFreed - just clean up the entry itself
        //
        // This prevents a critical bug where:
        // - Old instance at address X is garbage collected, callback is queued
        // - Child context (and its cache) is destroyed
        // - New instance is allocated at address X in a different cache
        // - Old callback fires and would incorrectly call onObjectFreed on NEW instance
        if (entry.is_orphaned) {
            log.debug("[weakCallback] ORPHANED: instance={*} - cache was destroyed, skipping cleanup", .{entry.instance});
            // Just dispose our wrapper handle - don't touch the cache or call onObjectFreed
            // The cache allocator should still be valid since we're called during deinitWithoutCallbacks
            disposeEntryWrapper(entry);
            entry.cache.allocator.destroy(entry);
            return;
        }

        log.debug("[weakCallback] ENTRY: instance={*} cache={*} vtable={*} state={*}", .{ entry.instance, entry.cache, entry.original_vtable, entry.original_state });

        // CRITICAL: Validate that this entry is still in the cache before removing.
        // Due to memory reuse (SlabAllocator/ArenaAllocator), the same instance address
        // can be used for different objects over time. If:
        // 1. Object A at address X is cached with entry E1
        // 2. Object A is garbage collected (E1's weak callback fires)
        // 3. Object B reuses address X and is cached with entry E2
        // 4. E1's weak callback runs and removes by key X
        // Then E2 (the NEW entry) would be incorrectly removed!
        //
        // The fix: Use fetchRemove and verify the removed entry matches our entry.
        // If it doesn't match, the entry was replaced - put it back and skip cleanup.
        if (entry.cache.cache.fetchRemove(entry.instance)) |kv| {
            if (kv.value != entry) {
                // The entry was replaced by a new one - put it back!
                log.debug("[weakCallback] STALE ENTRY: instance={*} - entry replaced, restoring new entry", .{entry.instance});
                entry.cache.cache.put(entry.instance, kv.value) catch {};
                // Just dispose our (stale) wrapper and entry, don't call onObjectFreed
                disposeEntryWrapper(entry);
                entry.cache.allocator.destroy(entry);
                return;
            }
        } else {
            // Entry not in cache at all - already removed by another path
            log.debug("[weakCallback] NOT FOUND: instance={*}", .{entry.instance});
            disposeEntryWrapper(entry);
            entry.cache.allocator.destroy(entry);
            return;
        }

        // CRITICAL: Verify the instance hasn't been reused for a different object.
        // The SlabAllocator can reuse instance addresses. If:
        // 1. Old instance A at address X is garbage collected
        // 2. This callback is queued but not yet run
        // 3. New instance B is allocated at address X (different type or re-init)
        // 4. This callback runs and would incorrectly deinit instance B
        //
        // Detection: Compare the current vtable AND state with what we stored.
        // - If vtable differs, the address was reused for a different type
        // - If state differs (even with same vtable), it's a new instance of same type
        log.debug("[weakCallback] VTABLE_CHECK: instance={*} orig_vtable={*} curr_vtable={*} orig_state={*} curr_state={*}", .{ entry.instance, entry.original_vtable, entry.instance.vtable, entry.original_state, entry.instance.state });
        if (slotReissued(entry)) {
            log.debug("[weakCallback] INSTANCE REUSED: instance={*} - vtable/state/generation mismatch, skipping cleanup", .{entry.instance});
            // Don't call onObjectFreed - the instance at this address is different
            disposeEntryWrapper(entry);
            entry.cache.allocator.destroy(entry);
            return;
        }

        // Step 1: Check if context teardown is in progress
        // If the CleanupCoordinator is handling teardown, we still need to ensure
        // type-specific cleanup happens. Previously we skipped onObjectFreed here
        // assuming "wrapper_cache.deinit handles it", but if the weak callback fires
        // BEFORE wrapper_cache.deinit iterates to this entry, the entry would be
        // removed from the cache and the instance's deinit would never be called.
        //
        // The fix: Check if cleanup was already started for this instance.
        // If not, call onObjectFreed to trigger the type's deinit.
        if (runtime.cleanup_coordinator.isContextTearingDown()) {
            // Note: entry already removed from cache above

            // Check if this instance was already cleaned up, and whether
            // another realm still wraps it.
            if (!runtime.instance_lifecycle.isCleanupStarted(entry.instance) and
                !wrappedElsewhere(entry.instance, entry.cache))
            {
                // Not yet cleaned up - call onObjectFreed to trigger deinit
                runtime.gc.onObjectFreed(entry.instance);
            }

            disposeEntryWrapper(entry);
            entry.cache.allocator.destroy(entry);
            return;
        }

        // Step 2: Check if instance cleanup already started (lifecycle tracking)
        // This prevents double-cleanup if Node.deinit was already called
        if (runtime.instance_lifecycle.isCleanupStarted(entry.instance)) {
            // Already being cleaned up - just dispose handles, and free the
            // storage a completed cleanup left (slotReissued was ruled out above).
            // Note: entry already removed from cache above
            if (runtime.instance_lifecycle.isCleanedUp(entry.instance)) runtime.gc.releaseStorage(entry.instance);
            disposeEntryWrapper(entry);
            entry.cache.allocator.destroy(entry);
            return;
        }

        // Step 3: Entry already removed from cache at the top (with validation)

        // An instance the ENGINE still owns is not freed when JS drops its
        // wrapper: a node in a tree is reachable from its parent, a window's
        // document from its browsing context, and neither pointer is visible
        // to V8. Freeing here left the parent holding a dangling child, and
        // the next walk over it - teardown, childNodes, textContent - read
        // freed memory. Only the wrapper goes; a later wrap makes a fresh one,
        // and the instance is freed when its tree is torn down, or once it is
        // removed from the tree and its next wrapper is collected.
        if (engineOwns(entry.instance)) {
            log.debug("[weakCallback] ENGINE-OWNED: instance={*} - wrapper released, instance kept", .{entry.instance});
            disposeEntryWrapper(entry);
            entry.cache.allocator.destroy(entry);
            return;
        }

        // Another realm's cache still wraps this instance: only this
        // realm's wrapper goes. See `live_caches`.
        if (wrappedElsewhere(entry.instance, entry.cache)) {
            disposeEntryWrapper(entry);
            entry.cache.allocator.destroy(entry);
            return;
        }

        // Step 4: Clean up the Zig instance via GC integration
        // This calls the type's deinit function (e.g., Response.deinit)
        // which frees all owned resources (headers, body, URL list, etc.)
        // and returns the Instance handle to the SlabAllocator
        runtime.gc.onObjectFreed(entry.instance);

        // Step 5: Dispose the Global<Object>* handle
        disposeEntryWrapper(entry);

        // Step 6: Free the CacheEntry
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

    /// Flag indicating the cache is being torn down.
    /// When true, markAsCleanedUp becomes a no-op to prevent
    /// re-entrant access during deinit iteration.
    is_tearing_down: bool = false,

    /// V8 Context (unused currently, kept for future extensions)
    context: *v8.Context,

    /// Whether this cache is in `live_caches`.
    registered: bool = false,

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
        installTreeHooks();
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
    /// This also calls gc.onObjectFreed for each instance to ensure
    /// type-specific deinit is called (since weak callbacks may not fire
    /// during shutdown).
    pub fn deinit(self: *Self) void {
        // Mark as tearing down to prevent re-entrant access during cleanup.
        // When Node.deinit calls markInstanceCleanedUp, it will be a no-op.
        self.is_tearing_down = true;

        // PHASE 1: Clear ALL weak callbacks first to prevent any from firing
        // during cleanup. This must happen before any cleanup to avoid races
        // where a weak callback tries to free an already-freed entry.
        {
            var iter = self.cache.valueIterator();
            while (iter.next()) |entry_ptr| {
                const entry = entry_ptr.*;
                v8.v8_Global_ClearWeak(@ptrCast(entry.wrapper));
            }
        }

        // PHASE 2: Now safe to clean up all entries (no weak callbacks can fire)
        log.debug("[wrapper_cache.deinit] cache={*} PHASE 2: Processing {} entries", .{ self, self.cache.count() });

        // Debug: dump all entries at deinit time
        {
            var debug_iter = self.cache.iterator();
            while (debug_iter.next()) |kv| {
                const inst = kv.key_ptr.*;
                const ent = kv.value_ptr.*;
                const NodeImpl = @import("impls").Node;
                var is_iframe_str: []const u8 = "no";
                var local_name_str: []const u8 = "null";
                if (NodeImpl.getInternalState(inst)) |node_internal| {
                    if (node_internal.local_name) |ln| {
                        local_name_str = ln.asSlice();
                        if (std.mem.eql(u8, ln.asSlice(), "iframe")) {
                            is_iframe_str = "YES";
                        }
                    }
                } else {
                    local_name_str = "no_internal";
                }
                log.debug("[wrapper_cache.deinit] ENTRY: instance={*} entry={*} local_name={s} is_iframe={s} vtable={*} state={*}", .{ inst, ent, local_name_str, is_iframe_str, inst.vtable, inst.state });
            }
        }
        var iter = self.cache.valueIterator();
        var processed: usize = 0;
        var skipped_cleaned: usize = 0;
        var skipped_started: usize = 0;
        var iframe_count: usize = 0;
        while (iter.next()) |entry_ptr| {
            const entry = entry_ptr.*;
            processed += 1;

            // Count iframes in cache
            const NodeImpl = @import("impls").Node;
            var is_iframe = false;
            if (NodeImpl.getInternalState(entry.instance)) |node_internal| {
                if (node_internal.local_name) |ln| {
                    if (std.mem.eql(u8, ln.asSlice(), "iframe")) {
                        iframe_count += 1;
                        is_iframe = true;
                    }
                }
            }

            // Only call deinit if not already cleaned up externally
            // Check both:
            // 1. instance_already_cleaned flag (set by markAsCleanedUp during tree walk)
            // 2. isCleanupStarted flag (set at start of Node.deinit)
            // The second check catches cases where markAsCleanedUp couldn't set the flag
            // (e.g., if is_tearing_down was already true or entry wasn't found)
            //
            // CRITICAL: Also check if the instance has been reused (vtable/state changed).
            // The SlabAllocator can reuse memory addresses multiple times. If the instance
            // at this address is different from what we cached, we must NOT call onObjectFreed
            // as it would deinit the wrong object.
            const is_started = runtime.instance_lifecycle.isCleanupStarted(entry.instance);
            const is_reused = slotReissued(entry);
            if (entry.instance_already_cleaned) {
                skipped_cleaned += 1;
                if (is_iframe) {
                    log.debug("[wrapper_cache.deinit] SKIP_CLEANED iframe instance={*}", .{entry.instance});
                }
            } else if (is_started) {
                skipped_started += 1;
                if (is_iframe) {
                    log.debug("[wrapper_cache.deinit] SKIP_STARTED iframe instance={*}", .{entry.instance});
                }
                // Its tree tore it down and left the storage: free that, and
                // only that - deinit has run.
                if (!is_reused and runtime.instance_lifecycle.isCleanedUp(entry.instance)) {
                    runtime.gc.releaseStorage(entry.instance);
                }
            } else if (is_reused) {
                // Instance was reused for a different object - don't call onObjectFreed
                // This can happen when:
                // 1. Old instance X was cached
                // 2. Old X was GC'd and deinit'd via weakCallback
                // 3. New instance Y was allocated at same address
                // 4. Y was also GC'd and deinit'd via weakCallback
                // 5. Yet another instance Z was allocated at same address
                // 6. Cache deinit runs, entry.instance points to Z, not Y
                log.debug("[wrapper_cache.deinit] SKIP_REUSED instance={*} orig_vtable={*} curr_vtable={*}", .{ entry.instance, entry.original_vtable, entry.instance.vtable });
            } else if (wrappedElsewhere(entry.instance, self)) {
                // Another realm's cache still wraps it; that one frees it.
            } else {
                if (is_iframe) {
                    log.debug("[wrapper_cache.deinit] DEINIT iframe instance={*}", .{entry.instance});
                }
                // Call GC integration to invoke type-specific deinit
                // This is essential for cleanup since weak callbacks may not fire during shutdown
                runtime.gc.onObjectFreed(entry.instance);
            }

            // Dispose the Global<Object>* handle
            disposeEntryWrapper(entry);

            // Free the CacheEntry
            self.allocator.destroy(entry);
        }

        log.debug("[wrapper_cache.deinit] Summary: processed={}, iframes={}, skipped_cleaned={}, skipped_started={}", .{ processed, iframe_count, skipped_cleaned, skipped_started });
        self.unregister();
        self.cache.deinit();
    }

    /// Clean up cache without calling onObjectFreed callbacks.
    /// Used during context manager teardown to avoid use-after-free
    /// when cleaning up cross-context references (e.g., iframe Windows).
    ///
    /// During normal operation, onObjectFreed is called to trigger
    /// type-specific cleanup. During teardown, all instances will be
    /// batch-freed anyway, so calling individual deinit functions
    /// can cause crashes if they reference already-freed memory.
    ///
    /// CRITICAL: This function marks entries as "orphaned" before cleanup.
    /// If V8's GC has already queued a weak callback that fires after this
    /// function returns, the callback will see the orphaned flag and skip
    /// calling onObjectFreed. This prevents a critical bug where a callback
    /// for an old instance at address X incorrectly deinits a NEW instance
    /// that reused address X.
    pub fn deinitWithoutCallbacks(self: *Self) void {
        // Mark as tearing down to prevent re-entrant access
        self.is_tearing_down = true;

        // PHASE 1: Mark all entries as orphaned FIRST.
        // This must happen before ClearWeak because if a callback fires
        // after ClearWeak but before we destroy entries, it needs to see
        // the orphaned flag to skip onObjectFreed.
        {
            var iter = self.cache.valueIterator();
            while (iter.next()) |entry_ptr| {
                const entry = entry_ptr.*;
                entry.is_orphaned = true;
            }
        }

        // PHASE 2: Try to clear weak callbacks.
        // This may not stop callbacks that V8 already queued.
        {
            var iter = self.cache.valueIterator();
            while (iter.next()) |entry_ptr| {
                const entry = entry_ptr.*;
                v8.v8_Global_ClearWeak(@ptrCast(entry.wrapper));
            }
        }

        // PHASE 3: Dispose V8 handles and destroy entries.
        // Since we've cleared weak callbacks, they should not fire.
        // The orphaned flag serves as a safety net - if a callback somehow
        // fires after this point (race with V8 GC), it will see is_orphaned=true.
        {
            var iter = self.cache.valueIterator();
            while (iter.next()) |entry_ptr| {
                const entry = entry_ptr.*;
                // Dispose the Global<Object>* handle
                disposeEntryWrapper(entry);
                // Free the CacheEntry
                self.allocator.destroy(entry);
            }
        }

        self.unregister();
        self.cache.deinit();
    }

    /// Join `live_caches` - on first use, when this cache's address is
    /// final (callers copy `init`'s result into place).
    fn register(self: *Self) void {
        if (self.registered) return;
        live_caches.append(std.heap.page_allocator, self) catch return;
        self.registered = true;
    }

    fn unregister(self: *Self) void {
        if (!self.registered) return;
        for (live_caches.items, 0..) |c, i| {
            if (c == self) {
                _ = live_caches.swapRemove(i);
                break;
            }
        }
        self.registered = false;
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
        self.register();

        // Allocate CacheEntry
        const entry = try self.allocator.create(CacheEntry);
        errdefer self.allocator.destroy(entry);

        entry.* = .{
            .wrapper = @ptrCast(wrapper),
            .instance = instance,
            .cache = self,
            .original_vtable = instance.vtable,
            .original_state = instance.state,
            .original_generation = runtime.SlabAllocator.generationOf(instance),
        };

        // Store in HashMap.
        //
        // An existing entry means this instance is being wrapped a second time,
        // which normally indicates a missed cache lookup upstream. Replacing the
        // value without releasing the old entry would leak its CacheEntry and its
        // Global<Object>* handle, and leave that handle's weak callback armed
        // pointing at memory we are about to orphan. Release it the same way
        // remove() does before taking over the key.
        if (self.cache.fetchRemove(instance)) |kv| {
            const old_entry = kv.value;
            log.debug(
                "[set] replacing existing wrapper for instance={*} old_entry={*} new_entry={*}",
                .{ instance, old_entry, entry },
            );
            v8.v8_Global_ClearWeak(@ptrCast(old_entry.wrapper));
            disposeEntryWrapper(old_entry);
            self.allocator.destroy(old_entry);
        }
        try self.cache.put(instance, entry);

        // Set weak callback for GC cleanup
        // The wrapper of a node in a tree - or of a window's document - is
        // held strongly, so its identity and its expandos survive a collection
        // the way they do in WebKit and Blink. It goes weak when the node
        // becomes a root (installTreeHooks), and the teardown sweep frees it
        // otherwise.
        if (engineOwns(instance)) {
            entry.strong = true;
        } else {
            v8.v8_Global_SetWeak(
                @ptrCast(wrapper),
                @ptrCast(entry),
                weakCallback,
            );
        }
    }

    /// Clear the entire cache
    ///
    /// Disposes all cached wrappers and clears the HashMap.
    /// Useful for testing or explicit cache invalidation.
    /// Uses two-phase cleanup like deinit() to prevent use-after-free
    /// from weak callbacks firing during cleanup.
    pub fn clear(self: *Self) void {
        // PHASE 1: Clear ALL weak callbacks first to prevent any from firing
        // during cleanup. This must happen before any cleanup to avoid races
        // where a weak callback tries to free an already-freed entry.
        {
            var iter = self.cache.valueIterator();
            while (iter.next()) |entry_ptr| {
                const entry = entry_ptr.*;
                v8.v8_Global_ClearWeak(@ptrCast(entry.wrapper));
            }
        }

        // PHASE 2: Now safe to clean up all entries (no weak callbacks can fire)
        var iter = self.cache.valueIterator();
        while (iter.next()) |entry_ptr| {
            const entry = entry_ptr.*;

            // Call GC integration to invoke type-specific deinit
            // This is essential for cleanup since weak callbacks were disabled
            if (!wrappedElsewhere(entry.instance, self)) runtime.gc.onObjectFreed(entry.instance);

            // Dispose the Global<Object>* handle
            disposeEntryWrapper(entry);

            // Free the CacheEntry
            self.allocator.destroy(entry);
        }

        self.cache.clearRetainingCapacity();
    }

    /// Mark an entry as already cleaned (instance deinit already called)
    ///
    /// This is used when the instance is being cleaned up by other means
    /// (e.g., Node.deinit cleaning up DOM tree). We mark it so that
    /// wrapper_cache.deinit() won't call onObjectFreed again (double-free).
    ///
    /// Also sets lifecycle tracking flags for coordinated cleanup (RC2 fix).
    ///
    /// We don't dispose the V8 handle here because we might still be in
    /// JavaScript execution context. The handle will be disposed during
    /// wrapper_cache.deinit().
    ///
    /// ## Parameters
    /// - instance: The Zig instance that has been cleaned up
    ///
    /// ## Returns
    /// true if entry was found and marked, false if not in cache
    pub fn markAsCleanedUp(self: *Self, instance: *runtime.Instance) bool {
        // CRITICAL: Skip during teardown to avoid HashMap access corruption.
        // During wrapper_cache.deinit, we're iterating and destroying entries.
        // Accessing the HashMap via get() during this phase can cause alignment
        // errors because entries are being deallocated.
        //
        // Instead, callers should use runtime.instance_lifecycle.markCleanupStarted()
        // which uses a SEPARATE tracking data structure that's safe to access
        // during teardown. The wrapper_cache.deinit loop already checks
        // isCleanupStarted() before calling gc.onObjectFreed.
        if (self.is_tearing_down) {
            return false;
        }

        if (self.cache.get(instance)) |entry| {
            // Clear weak callback to prevent it from firing
            v8.v8_Global_ClearWeak(@ptrCast(entry.wrapper));
            // Mark as already cleaned - deinit will skip onObjectFreed
            entry.instance_already_cleaned = true;
            return true;
        }
        return false;
    }

    /// Remove a specific entry from the cache
    ///
    /// Removes the entry completely, disposing the V8 handle.
    /// Use markAsCleanedUp() instead if still in JS execution context.
    ///
    /// ## Parameters
    /// - instance: The Zig instance to remove from cache
    ///
    /// ## Returns
    /// true if entry was found and removed, false if not in cache
    pub fn remove(self: *Self, instance: *runtime.Instance) bool {
        if (self.cache.fetchRemove(instance)) |kv| {
            const entry = kv.value;

            // Clear weak callback first to prevent it from firing
            v8.v8_Global_ClearWeak(@ptrCast(entry.wrapper));

            // Dispose the Global<Object>* handle
            disposeEntryWrapper(entry);

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
