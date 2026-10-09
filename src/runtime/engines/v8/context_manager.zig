//! V8 Context Manager
//!
//! Manages the mapping between V8 JavaScript contexts and WebIDL runtime contexts.
//! This bridge allows V8 callbacks to access WebIDL runtime services (logging, etc.)
//! without requiring global state.
//!
//! ## Architecture
//!
//! ```
//! V8 JavaScript Context
//!     ↓ (mapped via hash map)
//! Runtime Context (*ContextData)
//!     ↓ (contains)
//! - Logger (console.log, etc.)
//! - Allocator (memory management)
//! - Engine Context (back-reference to V8)
//! ```
//!
//! ## Thread Safety
//!
//! Each V8 isolate is single-threaded, so we use thread-local storage for the context map.
//! This ensures that each thread has its own independent context mapping.
//!
//! ## Usage
//!
//! ```zig
//! const v8 = @import("v8.zig");
//! const mgr = @import("v8/context_manager.zig");
//!
//! // In isolate setup:
//! mgr.init(allocator);
//! defer mgr.deinit();
//!
//! // In V8 callback:
//! fn constructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
//!     const isolate = info.getIsolate();
//!     const v8_ctx = v8.ffi.v8_Isolate_GetCurrentContext(isolate).?;
//!     const ctx = mgr.getOrCreate(v8_ctx, allocator) catch return;
//!
//!     // Now can use ctx for logging, allocation, etc.
//!     const instance = Interface.call_constructor( ctx) catch return;
//! }
//! ```

const std = @import("std");
const log = std.log.scoped(.v8_context);
const v8 = @import("ffi.zig");
const runtime = @import("runtime");
const V8EventLoop = @import("event_loop.zig").V8EventLoop;
const v8_engine = @import("engine.zig");
const intl_binding = @import("intl_binding.zig");
const fetch = @import("fetch");
const iface_bindings_mod = @import("interface_bindings.zig");
const helpers = @import("webidl").helpers;
const shadow_realm = @import("shadow_realm.zig");
const node_document = @import("dom").node_document;

/// Context mapping entry
pub const ContextEntry = struct {
    /// V8 context pointer (key)
    v8_ctx: *v8.Context,

    /// Runtime context data (owned)
    runtime_ctx: runtime.ContextData,

    /// Whether this entry owns the runtime context
    /// (and should deinit it when removed)
    owns_context: bool,

    /// Whether `v8_ctx` is this entry's own Global - a copy it took, or a
    /// context it created - rather than a handle its caller keeps and
    /// disposes. An owned handle is the last strong root of a destroyed page
    /// once the rest is released, so retiring the entry disposes it.
    owns_v8_ctx: bool = false,

    /// V8 event loop with timer support (owned if owns_context is true)
    event_loop: ?*V8EventLoop,

    /// Associated realm for this context (for cross-realm support)
    /// Each V8 context has its own realm with intrinsics, global object, etc.
    realm: ?*runtime.Realm,

    /// Parent context entry (for iframe hierarchy)
    /// Null for top-level/main contexts
    parent_entry: ?*ContextEntry,

    /// Child context entries (iframes, workers, etc.)
    /// Uses unmanaged ArrayList for Zig 0.15+ API
    children: std.ArrayListUnmanaged(*ContextEntry),

    /// Allocator used for this entry (needed for children list)
    allocator: std.mem.Allocator,

    /// Window instance for this context (for cross-realm support)
    /// This Window instance IS bound to the V8 global object, enabling
    /// `iframe.contentWindow.DOMRectReadOnly` to work correctly.
    /// Set during createChildContext() for iframe contexts.
    window_instance: ?*runtime.Instance = null,

    // The realm's document URL lives on its runtime context
    // (runtime_ctx.document_url): realm state, not engine state.

    /// Set as destroyChildContext starts on this entry. Its teardown runs
    /// arbitrary deinit code - a Window, a DOM tree, iframe elements - and any
    /// of it can reach this entry again; the entry is retired, never freed,
    /// so the flag stays readable for the manager's lifetime.
    destroying: bool = false,
};

/// Thread-local context manager state
threadlocal var manager_state: ?ManagerState = null;

/// Callback type for registering globals on child contexts (iframes)
/// This is called by createChildContext after the context is created
/// to allow the browser layer to register setTimeout, setInterval, etc.
pub const ChildContextGlobalsCallback = *const fn (
    isolate: *v8.Isolate,
    context: *v8.Context,
    global: *v8.Object,
) void;

/// Thread-local callback for registering globals on child contexts
/// Set by browser layer via setChildContextGlobalsCallback()
threadlocal var child_context_globals_callback: ?ChildContextGlobalsCallback = null;

/// Callback type for a child window whose document is being destroyed - its
/// iframe removed, or its context torn down. The browser layer owns state
/// that outlives a document unless something ends it - HTML's "unloading
/// document cleanup steps" clear the window's map of active timers - and the
/// runtime layer cannot reach it, so it asks through this. Called while the
/// context and its global are still intact; running it twice for one context
/// finds nothing the second time.
pub const ChildWindowCleanupCallback = *const fn (context: *v8.Context) void;

/// Set by the browser layer via setChildWindowCleanupCallback().
threadlocal var child_window_cleanup_callback: ?ChildWindowCleanupCallback = null;

// ============================================================================
// Accessor Context Stack
// ============================================================================
//
// V8's GetEnteredOrMicrotaskContext doesn't work correctly for cross-context
// property access (e.g., iframe accessing parent.document). When a property
// accessor is called on a cross-context object, V8 enters the object's context,
// making it impossible to determine the original accessor.
//
// This stack tracks the accessor Window explicitly. Script execution pushes the
// executing Window onto this stack, and property accessors can query it to get
// the correct accessor for security checks.

/// Maximum depth of the accessor stack (nested script execution)
const ACCESSOR_STACK_MAX_DEPTH = 32;

/// Thread-local accessor stack
threadlocal var accessor_stack: [ACCESSOR_STACK_MAX_DEPTH]?*runtime.Instance = [_]?*runtime.Instance{null} ** ACCESSOR_STACK_MAX_DEPTH;
threadlocal var accessor_stack_depth: usize = 0;

/// Push a Window onto the accessor stack before script execution.
/// Call this before running JavaScript code to track which Window is the accessor.
pub fn pushAccessorWindow(window: *runtime.Instance) void {
    if (accessor_stack_depth < ACCESSOR_STACK_MAX_DEPTH) {
        accessor_stack[accessor_stack_depth] = window;
        accessor_stack_depth += 1;
    } else {
        log.debug("[context_manager] WARNING: accessor stack overflow\n", .{});
    }
}

/// Pop a Window from the accessor stack after script execution.
/// Call this after running JavaScript code.
pub fn popAccessorWindow() void {
    if (accessor_stack_depth > 0) {
        accessor_stack_depth -= 1;
        accessor_stack[accessor_stack_depth] = null;
    }
}

/// Get the current accessor Window (top of the stack).
/// Returns the Window that is currently executing JavaScript code.
/// Returns null if no script is executing (direct API call).
pub fn getCurrentAccessorWindow() ?*runtime.Instance {
    if (accessor_stack_depth > 0) {
        return accessor_stack[accessor_stack_depth - 1];
    }
    return null;
}

/// Set the callback for registering globals on child contexts
/// This should be called by the browser layer during initialization
pub fn setChildContextGlobalsCallback(callback: ChildContextGlobalsCallback) void {
    child_context_globals_callback = callback;
}

/// Clear the child context globals callback
pub fn clearChildContextGlobalsCallback() void {
    child_context_globals_callback = null;
}

/// Set the callback run as a child window's document is destroyed.
pub fn setChildWindowCleanupCallback(callback: ChildWindowCleanupCallback) void {
    child_window_cleanup_callback = callback;
}

/// Clear the child window cleanup callback
pub fn clearChildWindowCleanupCallback() void {
    child_window_cleanup_callback = null;
}

/// Manager state (thread-local)
const ManagerState = struct {
    /// Allocator for internal structures
    allocator: std.mem.Allocator,

    /// Map from V8 context pointer to runtime context
    /// Key: usize (casted from *v8.Context)
    /// Value: *ContextEntry (pointer to heap-allocated entry)
    ///
    /// IMPORTANT: We store *ContextEntry (pointer) instead of ContextEntry (value)
    /// because HashMap moves values during rehash. If we stored values directly,
    /// any pointer into entry.runtime_ctx (like Window.ctx or Element.ctx)
    /// would become dangling after rehash. By heap-allocating entries and
    /// storing pointers, the entries themselves don't move when HashMap grows.
    contexts: std.AutoHashMap(usize, *ContextEntry),

    /// Entries taken out of `contexts` but not yet freed.
    ///
    /// Instances created in a context hold `ctx == &entry.runtime_ctx` - that is
    /// the whole reason entries are heap-allocated, per the note above. Neither
    /// `destroyChildContext` nor `removeContext` destroys those Instances; they
    /// are deliberately left for the slab's wholesale teardown. So freeing the
    /// entry underneath them left every one of them pointing at
    /// DebugAllocator-poisoned memory, where `_v8_wrapper_cache_storage` reads
    /// back as 0xAAAA_AAAA_AAAA_AAAA: non-null, and not 8-aligned, so
    /// `markInstanceCleanedUp` panicked in its `@alignCast` instead of quietly
    /// returning a wrong answer. Retiring the entry keeps every stale `ctx`
    /// pointing at a real, inert ContextData until `deinit` drains this list.
    ///
    /// Costs one entry plus its ContextData's own buffers per destroyed context,
    /// for the lifetime of the manager. That is retention, not a leak - the drain
    /// frees all of it - and it buys away a class of use-after-free that no
    /// caller of `instance.ctx` can defend against on its own.
    retired: std.ArrayListUnmanaged(*ContextEntry) = .empty,

    /// Default allocator to use for new contexts
    default_allocator: std.mem.Allocator,

    /// Flag indicating we're in the middle of full teardown (deinit)
    /// When true, destroyChildContext should be a no-op since all contexts
    /// are being torn down anyway
    is_tearing_down: bool = false,
};

/// Initialize the context manager for this thread
///
/// Must be called before using any context manager functions.
/// Each thread must call init() independently.
///
/// Thread safety: Thread-local, no synchronization needed
pub fn init(allocator: std.mem.Allocator) !void {
    if (manager_state != null) {
        return error.AlreadyInitialized;
    }

    manager_state = ManagerState{
        .allocator = allocator,
        .contexts = std.AutoHashMap(usize, *ContextEntry).init(allocator),
        .default_allocator = allocator,
    };
}

/// Deinitialize the context manager and free all contexts
///
/// Cleans up all runtime contexts that were created by the manager.
/// After calling deinit(), init() must be called again before use.
///
/// Uses CleanupCoordinator to ensure proper ordering and prevent
/// race conditions between context teardown and GC-driven cleanup.
///
/// Thread safety: Thread-local, no synchronization needed
pub fn deinit() void {
    log.debug("[context_manager.deinit] ENTERING DEINIT\n", .{});
    if (manager_state) |*state| {
        const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
        const cleanup_coordinator = runtime.cleanup_coordinator;

        // Create coordinator for this teardown
        var coordinator = cleanup_coordinator.CleanupCoordinator.init(state.allocator);
        defer coordinator.deinit();

        // Set coordinator as active so GC callbacks can check teardown state
        cleanup_coordinator.setActiveCoordinator(&coordinator);
        defer cleanup_coordinator.setActiveCoordinator(null);

        // Begin coordinated cleanup - signals GC callbacks to skip
        coordinator.beginContextCleanup();

        // Set legacy teardown flag for backwards compatibility
        // When wrapper_cache.deinit() triggers onObjectFreed for iframes,
        // the iframe cleanup will try to call destroyChildContext. We need
        // to skip those calls since we're already tearing everything down.
        state.is_tearing_down = true;

        // Phase: Static Registries (cleanup before context-specific resources)
        // Clean up Intl registries (safety net for entries not GC'd)
        // This must be done before contexts are destroyed since weak callbacks
        // may still reference registry data
        coordinator.cleanupPhase(.static_registries);
        intl_binding.deinitAllRegistries();

        // Clean up ObservableArray static registry
        // This is a safety net for states not cleaned up via V8 GC weak callbacks
        @import("observable_array.zig").cleanupAll();

        // Deinit all owned runtime contexts
        // Note: The order doesn't matter for cleanup because we skip onObjectFreed
        // during teardown (is_tearing_down flag prevents nested calls).
        log.debug("[context_manager.deinit] Starting context iteration, {} contexts in map\n", .{state.contexts.count()});
        var it = state.contexts.valueIterator();
        while (it.next()) |entry_ptr| {
            const entry = entry_ptr.*; // Dereference the pointer to get *ContextEntry
            log.debug("[context_manager.deinit] Processing context entry, owns_context={}, window_instance={?}\n", .{ entry.owns_context, entry.window_instance });
            if (entry.owns_context) {
                log.debug("[context_manager.deinit] Owns context - processing\n", .{});
                // A pointer, not a copy. Every Instance created in this context
                // holds `ctx == &entry.runtime_ctx`, so anything that clears a
                // field has to land on the entry's own ContextData; on a copy it
                // is a no-op and the entry goes on advertising resources this
                // function has already freed.
                const ctx_data = &entry.runtime_ctx;

                // Phase: ShadowRealm cleanup
                // Dispose any ShadowRealm contexts that were created by this context.
                // This must happen BEFORE we destroy the wrapper cache and context data,
                // as ShadowRealm cleanup may need to access V8 handles.
                const raw_addr = v8.v8_Context_GetRawAddress(entry.v8_ctx);
                if (raw_addr) |addr| {
                    shadow_realm.disposeByInitiator(addr);
                }

                // Phase: Location cleanup
                // Location may not be in the wrapper cache if never accessed from JS.
                // Clean it up explicitly to prevent memory leaks.
                // Strategy:
                // 1. Remove Location from wrapper_cache FIRST (if present) - disposes V8 handle
                // 2. Call gc.onObjectFreed to clean InternalState AND free Instance to slab
                // 3. wrapper_cache.deinit won't find Location (already removed) - no double-free
                if (entry.window_instance) |window_instance| {
                    std.log.debug("[context_manager.deinit] Processing Window {*} for Location cleanup", .{window_instance});
                    const WindowImpl = @import("impls").Window;
                    if (WindowImpl.getInternal(window_instance)) |window_internal| {
                        if (window_internal.location) |loc| {
                            std.log.debug("[context_manager.deinit] Explicit Location cleanup for {*}", .{loc});
                            // Step 1: Remove from wrapper cache if present
                            if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
                                const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
                                _ = cache_ptr.remove(loc);
                            }
                            // Step 2: Clean up InternalState and free Instance
                            runtime.gc.onObjectFreed(loc);
                            window_internal.location = null; // Prevent double-free
                        } else {
                            std.log.debug("[context_manager.deinit] Window {*} has no Location", .{window_instance});
                        }
                    } else {
                        std.log.debug("[context_manager.deinit] Window {*} has no internal state", .{window_instance});
                    }
                } else {
                    std.log.debug("[context_manager.deinit] Context entry has no window_instance", .{});
                }

                // Phase: DOM Tree cleanup
                // Clean up Window instance and its Document FIRST
                // This cleans up the DOM tree, and each Node.deinit removes itself
                // from the wrapper cache to prevent double-free.
                // CRITICAL: We must call Window.deinit to trigger Document.deinit → Node.deinit
                // which recursively cleans up all DOM nodes. Without this, DOM nodes
                // (including HTMLScriptElement in iframes) would leak.
                // To prevent double-free, we remove Window from wrapper cache FIRST.
                coordinator.cleanupPhase(.dom_tree);

                if (entry.window_instance) |window_instance| {
                    const WindowImpl = @import("impls").Window;
                    log.debug("[context_manager.deinit] DOM Tree cleanup: Window.deinit for {*}", .{window_instance});

                    // Remove Window from wrapper cache FIRST to prevent double-free
                    if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
                        const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
                        _ = cache_ptr.remove(window_instance);
                    }

                    // Now call Window.deinit to clean up Document and DOM tree
                    WindowImpl.deinit(window_instance);
                    log.debug("[context_manager.deinit] DOM Tree cleanup: Window.deinit DONE", .{});
                } else {
                    log.debug("[context_manager.deinit] DOM Tree cleanup: NO window_instance for context", .{});
                }

                // Phase: Orphaned Iframe cleanup
                // Clean up HTMLIFrameElements that were removed from the DOM (via iframe.remove())
                // but never explicitly deinited. These are still in the wrapper cache and their
                // BrowsingContext needs to be freed. We must do this before wrapper_cache.deinit()
                // to ensure IFrameIntegration.deinit() → BrowsingContext.deinit() is called.
                //
                // We identify iframes by checking Node's local_name == "iframe".
                log.debug("[context_manager.deinit] Starting orphaned iframe cleanup phase\n", .{});
                if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
                    log.debug("[context_manager.deinit] Got wrapper cache storage\n", .{});
                    const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
                    const NodeImpl = @import("impls").Node;
                    const HTMLIFrameElementIface = @import("interfaces").HTMLIFrameElement;

                    // Collect iframe instances first to avoid modifying cache while iterating
                    var iframe_instances: [64]*runtime.Instance = undefined;
                    var iframe_count: usize = 0;

                    var iter = cache_ptr.cache.iterator();
                    while (iter.next()) |kv| {
                        const instance = kv.key_ptr.*;

                        // Skip if already being cleaned up
                        if (runtime.instance_lifecycle.isCleanupStarted(instance)) continue;

                        // Check if this is an HTMLIFrameElement by checking local_name
                        if (NodeImpl.getInternalState(instance)) |node_internal| {
                            if (node_internal.local_name) |ln| {
                                if (std.mem.eql(u8, ln.asSlice(), "iframe")) {
                                    if (iframe_count < iframe_instances.len) {
                                        iframe_instances[iframe_count] = instance;
                                        iframe_count += 1;
                                    }
                                }
                            }
                        }
                    }

                    // Now clean up the collected iframes
                    log.debug("[context_manager.deinit] Cleaning up {} orphaned iframes\n", .{iframe_count});
                    for (iframe_instances[0..iframe_count]) |iframe_instance| {
                        log.debug("[context_manager.deinit] Calling deinit for iframe instance {*}\n", .{iframe_instance});
                        HTMLIFrameElementIface.deinit(iframe_instance);
                    }
                } else {
                    log.debug("[context_manager.deinit] No wrapper cache storage found\n", .{});
                }

                // Phase: Wrapper Cache cleanup
                // Clean up V8 wrapper cache WITH callbacks
                // Now safe to call deinit() because:
                // 1. DOM nodes already removed themselves from cache via Node.deinit
                // 2. Orphaned iframes already cleaned up explicitly above
                // 3. Remaining entries are non-DOM objects (AbortController, etc.)
                // 4. These need their deinit called to free InternalState
                coordinator.cleanupPhase(.wrapper_cache);
                if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
                    const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
                    cache_ptr.deinit();
                    ctx_data.getAllocator().destroy(cache_ptr);
                    // The realm and context-data phases below still run, and both
                    // can reach an Instance whose ctx is this one. Leave no pointer
                    // to the cache we just freed.
                    ctx_data.clearV8WrapperCacheStorage();
                }

                // Phase: Event Loop cleanup
                // Clean up V8 event loop (must be done before context deinit)
                coordinator.cleanupPhase(.event_loop);
                if (entry.event_loop) |ev_loop| {
                    ev_loop.deinit();
                    ctx_data.getAllocator().destroy(ev_loop);
                }

                // Phase: Realm cleanup
                coordinator.cleanupPhase(.realm);
                if (entry.realm) |realm| {
                    @import("realm_v8.zig").disposeIntrinsics(realm);
                    realm.deinit();
                }

                // Clean up children list (entries themselves are in the map)
                var children = entry.children;
                children.deinit(entry.allocator);

                // Phase: Context Data cleanup
                coordinator.cleanupPhase(.context_data);
                ctx_data.deinit();
            }

            entry.runtime_ctx.clearDocumentUrl();

            // Free the heap-allocated entry itself
            state.allocator.destroy(entry);
        }

        // Free the entries retired earlier by removeContext/destroyChildContext.
        // Held until now because Instances created in those contexts still point
        // at `entry.runtime_ctx`; by this point every Instance is going away with
        // the slab, so the ContextData can go too.
        for (state.retired.items) |entry| {
            if (entry.owns_context) entry.runtime_ctx.deinit();
            state.allocator.destroy(entry);
        }
        state.retired.deinit(state.allocator);

        // Mark cleanup complete
        coordinator.endContextCleanup();

        // Free the hash map
        state.contexts.deinit();
        manager_state = null;
    }
}

/// Get or create a runtime context for the given V8 context
///
/// If a runtime context already exists for this V8 context, returns it.
/// Otherwise, creates a new runtime context with default options.
///
/// The returned context is valid until:
/// - removeContext() is called for this V8 context
/// - deinit() is called
///
/// Thread safety: Thread-local, no synchronization needed
///
/// Arguments:
/// - v8_ctx: V8 context pointer
/// - allocator: Allocator to use for the runtime context (if created)
///
/// Returns: Runtime context pointer (borrowed, do not free)
pub fn getOrCreate(v8_ctx: *v8.Context, allocator: std.mem.Allocator) !runtime.Context {
    // For backwards compatibility, call with null isolate (no timer support)
    return getOrCreateWithIsolate(v8_ctx, null, allocator);
}

/// Get or create a runtime context with an external timer/event loop
///
/// Use this when you already have a V8EventLoop (e.g., in BrowserContext) and want
/// to share it with all runtime contexts. This ensures all timers use the same
/// libuv loop and are polled together.
///
/// Arguments:
/// - v8_ctx: V8 context pointer
/// - timer: External timer interface to use (optional)
/// - event_loop: External event loop interface to use (optional)
/// - allocator: Allocator for the runtime context
///
/// Returns: Runtime context pointer (borrowed, do not free)
pub fn getOrCreateWithExternalEventLoop(
    v8_ctx: *v8.Context,
    timer: ?runtime.TimerInterface,
    event_loop: ?@import("event_loop").EventLoop,
    allocator: std.mem.Allocator,
) !runtime.Context {
    const state = &(manager_state orelse return error.NotInitialized);

    // Use the raw V8 internal address as the key
    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return error.InvalidContext;
    const key = @intFromPtr(raw_addr);

    // Check if context already exists
    if (state.contexts.get(key)) |entry| {
        return &entry.runtime_ctx;
    }

    // Create new runtime context with external timer/event loop
    var ctx_data = try runtime.ContextData.init(allocator, .{
        .colored = false,
        .show_timestamp = false,
        .show_labels = false,
        .engine_ctx = @ptrCast(v8_ctx),
        .timer = timer,
        .event_loop = event_loop,
    });
    errdefer ctx_data.deinit();

    // Initialize V8 wrapper cache for this context
    const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
    const cache_ptr = try allocator.create(WrapperCache);
    errdefer allocator.destroy(cache_ptr);

    cache_ptr.* = try WrapperCache.init(allocator, v8_ctx);
    errdefer cache_ptr.deinit();

    // Store cache in runtime context
    ctx_data.setV8WrapperCacheStorage(@ptrCast(cache_ptr));
    // The realm's agent: the isolate the context was just made in, which is
    // the current one. Operations that enter the realm from outside it enter
    // this (engine.enterRealm) - a worker's is never the page's.
    ctx_data.agent = @ptrCast(v8.v8_Isolate_GetCurrent());

    // Heap-allocate the entry so it doesn't move when HashMap rehashes
    const entry = try state.allocator.create(ContextEntry);
    errdefer state.allocator.destroy(entry);

    entry.* = ContextEntry{
        .v8_ctx = v8_ctx,
        .runtime_ctx = ctx_data,
        .owns_context = true,
        .event_loop = null, // We don't own the external event loop
        .realm = null,
        .parent_entry = null,
        .children = .empty,
        .allocator = allocator,
    };

    // Store pointer in map - entry won't move even if HashMap rehashes
    try reserveRetirement(state);
    try state.contexts.put(key, entry);

    return &entry.runtime_ctx;
}

/// Bind a Window instance to an existing context's global object.
/// This enables `frames[0]` to work by:
/// 1. Creating a Window runtime.Instance
/// 2. Binding it to the V8 global object's internal fields
/// 3. Storing the Window in the context entry for browsing context linking
///
/// Call this after getOrCreateWithExternalEventLoop() to enable cross-realm features.
///
/// Returns the created Window instance.
pub fn bindWindowToContext(v8_ctx: *v8.Context, isolate: *v8.Isolate, allocator: std.mem.Allocator) !*runtime.Instance {
    const state = &(manager_state orelse return error.NotInitialized);

    // Get the raw V8 internal address as the key
    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return error.InvalidContext;
    const key = @intFromPtr(raw_addr);

    // Get the context entry - must already exist from getOrCreateWithExternalEventLoop
    const entry = state.contexts.get(key) orelse return error.ContextNotFound;

    // Don't create another Window if one already exists
    if (entry.window_instance) |existing| {
        return existing;
    }

    // Create Window bound to global using the internal helper
    const window_instance = try createWindowBoundToGlobal(
        allocator,
        &entry.runtime_ctx,
        v8_ctx,
        isolate,
    );

    // Store in the context entry for browsing context linking
    entry.window_instance = window_instance;

    // Create realm if it doesn't exist (e.g., context was created via getOrCreateWithExternalEventLoop)
    // This is required for cross-realm support
    if (entry.realm == null) {
        const realm = try runtime.Realm.init(allocator, .{
            .engine_realm = @ptrCast(v8_ctx),
            .agent = @ptrCast(isolate),
            .context_type = .window,
            .global_object = window_instance, // Set directly since we have the Window
        });
        // Populate intrinsics for cross-realm support
        _ = @import("realm_v8.zig").populateIntrinsics(realm);

        // Store realm in entry and runtime context
        entry.realm = realm;
        entry.runtime_ctx.setRealm(realm);
    } else {
        // Realm already exists, just update global_object
        entry.realm.?.setGlobalObject(window_instance);
    }

    return window_instance;
}

/// Get or create a runtime context for the given V8 context with full timer support
///
/// If a runtime context already exists for this V8 context, returns it.
/// Otherwise, creates a new runtime context with V8EventLoop for timer support.
///
/// The returned context is valid until:
/// - removeContext() is called for this V8 context
/// - deinit() is called
///
/// Thread safety: Thread-local, no synchronization needed
///
/// Arguments:
/// - v8_ctx: V8 context pointer
/// - isolate: V8 isolate (optional, needed for timer support)
/// - allocator: Allocator to use for the runtime context (if created)
///
/// Returns: Runtime context pointer (borrowed, do not free)
pub fn getOrCreateWithIsolate(v8_ctx: *v8.Context, isolate: ?*v8.Isolate, allocator: std.mem.Allocator) !runtime.Context {
    const state = &(manager_state orelse return error.NotInitialized);

    // Use the raw V8 internal address as the key (stable across Global/Local conversions)
    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return error.InvalidContext;
    const key = @intFromPtr(raw_addr);

    // Check if context already exists
    if (state.contexts.get(key)) |entry| {
        return &entry.runtime_ctx;
    }

    // The entry keeps its OWN handle, so the caller's stays the caller's to
    // release whichever path this takes. Storing the caller's handle made it
    // the entry's on this path only, so no caller could ever release one: the
    // constructor binding leaked a Global<Context> per `new X()`, each keeping
    // its page's whole native context alive.
    const copy_isolate = isolate orelse (v8.v8_Isolate_GetCurrent() orelse return error.InvalidContext);
    const entry_ctx: *v8.Context = @ptrCast(v8.v8_Context_GlobalHandle_New(copy_isolate, v8_ctx) orelse return error.InvalidContext);
    errdefer v8.v8_Context_Dispose(entry_ctx);

    // Create V8 event loop with timer support if isolate is provided
    var event_loop_ptr: ?*V8EventLoop = null;
    var timer_interface: ?runtime.TimerInterface = null;
    var event_loop_interface: ?@import("event_loop").EventLoop = null;

    if (isolate) |iso| {
        const ev_loop = try allocator.create(V8EventLoop);
        errdefer allocator.destroy(ev_loop);

        ev_loop.* = try V8EventLoop.init(iso, allocator);
        errdefer ev_loop.deinit();

        event_loop_ptr = ev_loop;
        timer_interface = ev_loop.timerInterface();
        event_loop_interface = ev_loop.eventLoop();
    }

    // Create new runtime context with V8 engine interface
    // The engine interface provides Promise creation, async iterators, and other
    // engine-agnostic operations that body methods (text(), json(), etc.) need.
    var ctx_data = try runtime.ContextData.init(allocator, .{
        .colored = false, // V8 callbacks shouldn't use colored output
        .show_timestamp = false,
        .show_labels = false,
        .engine_ctx = @ptrCast(entry_ctx), // Store V8 context as engine context
        .timer = timer_interface,
        .event_loop = event_loop_interface,
    });
    errdefer ctx_data.deinit();

    // Initialize V8 wrapper cache for this context
    const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
    const cache_ptr = try allocator.create(WrapperCache);
    errdefer allocator.destroy(cache_ptr);

    cache_ptr.* = try WrapperCache.init(allocator, entry_ctx);
    errdefer cache_ptr.deinit();

    // Store cache in runtime context
    ctx_data.setV8WrapperCacheStorage(@ptrCast(cache_ptr));
    // The realm's agent: the isolate the context was just made in, which is
    // the current one. Operations that enter the realm from outside it enter
    // this (engine.enterRealm) - a worker's is never the page's.
    ctx_data.agent = @ptrCast(v8.v8_Isolate_GetCurrent());

    // Create realm for cross-realm support (only if we have an isolate)
    // Per WebIDL, every context has an associated realm with intrinsics
    // Note: global_object is set to null here and will be populated later by
    // bindWindowToContext() when the Window instance is created
    var realm: ?*runtime.Realm = null;
    if (isolate) |iso| {
        realm = try runtime.Realm.init(allocator, .{
            .engine_realm = @ptrCast(entry_ctx),
            .agent = @ptrCast(iso),
            .context_type = .window, // Main context is a window
            .global_object = null, // Set by bindWindowToContext() after Window creation
        });
        errdefer if (realm) |r| r.deinit();

        // Populate realm intrinsics for cross-realm support
        _ = @import("realm_v8.zig").populateIntrinsics(realm.?);

        // Set realm on runtime context so impl code can access via instance.ctx.realm
        ctx_data.setRealm(realm.?);
    }

    // Heap-allocate the entry so it doesn't move when HashMap rehashes
    const entry = try state.allocator.create(ContextEntry);
    errdefer state.allocator.destroy(entry);

    entry.* = ContextEntry{
        .v8_ctx = entry_ctx,
        .owns_v8_ctx = true,
        .runtime_ctx = ctx_data,
        .owns_context = true,
        .event_loop = event_loop_ptr,
        .realm = realm,
        .parent_entry = null,
        .children = .empty,
        .allocator = allocator,
    };

    // Store pointer in map - entry won't move even if HashMap rehashes
    try reserveRetirement(state);
    try state.contexts.put(key, entry);

    // Return pointer to context data - stable because entry is heap-allocated
    return &entry.runtime_ctx;
}

/// Get an existing runtime context for the given V8 context
///
/// Returns null if no runtime context exists for this V8 context.
///
/// Thread safety: Thread-local, no synchronization needed
pub fn get(v8_ctx: *v8.Context) ?runtime.Context {
    const state = &(manager_state orelse return null);

    // Use the raw V8 internal address as the key (stable across Global/Local conversions)
    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return null;
    const key = @intFromPtr(raw_addr);

    if (state.contexts.get(key)) |entry| {
        return &entry.runtime_ctx;
    }

    return null;
}

/// Is a context with this raw address still registered?
///
/// Takes the ADDRESS, not the Global<Context>*, on purpose. `get()` above has to
/// call v8_Context_GetRawAddress to derive the key, which dereferences the handle -
/// so it cannot be used to ask "is this handle still valid?", because doing so is
/// the very use-after-free being tested for.
///
/// Callers that need to outlive a context (a queued microtask, say) must capture
/// `v8_Context_GetRawAddress` while the context is still alive and pass that key
/// here later.
pub fn isContextAddressAlive(raw_addr: usize) bool {
    const state = &(manager_state orelse return false);
    return state.contexts.contains(raw_addr);
}

/// Hydrate a V8 context restored from snapshot with the appropriate interfaces for the given scope
///
/// This function installs only the interfaces that are exposed in the given scope,
/// using the exposure metadata from WebIDL [Exposed] attributes.
///
/// Thread safety: Thread-local, no synchronization needed
///
/// Arguments:
/// - isolate: V8 isolate pointer
/// - v8_ctx: V8 context pointer (restored from snapshot)
/// - scope: The global scope kind to install interfaces for
pub fn hydrateContextFromSnapshot(
    isolate: *v8.Isolate,
    v8_ctx: *v8.Context,
    scope: helpers.GlobalScope,
) void {
    log.debug("[HYDRATE-SNAPSHOT] hydrateContextFromSnapshot called, context={*}, scope={s}\n", .{ v8_ctx, @tagName(scope) });

    // Use inline for to convert runtime scope to comptime for installForScope
    inline for (std.meta.fields(helpers.GlobalScope)) |field| {
        if (scope == @field(helpers.GlobalScope, field.name)) {
            // NOTE: Do NOT call installLazyConstructorsOnGlobal here!
            // The snapshot already contains all WebIDL constructors registered via initializeBindings().
            // Installing lazy getters would OVERWRITE the snapshot's constructors with fresh ones,
            // breaking prototype chain identity (instanceof checks would fail because the prototype
            // objects would be different from those in the snapshot).

            // Register legacy interface aliases (e.g., webkitURL = URL)
            // V8 snapshots don't preserve object property sets on the global,
            // so we must re-register these aliases at runtime after loading from snapshot.
            const interface_bindings = @import("interface_bindings.zig");
            interface_bindings.registerLegacyInterfaceAliases(isolate, v8_ctx);

            // NOTE: Do NOT call setupConstructorInheritance here!
            // The snapshot already contains properly configured prototype chains set up during
            // snapshot creation via FunctionTemplate::Inherit(). Re-calling this would create
            // new templates and potentially break the prototype chain identity.

            log.debug("[HYDRATE-SNAPSHOT] Context hydrated with legacy aliases, scope={s}\n", .{@tagName(scope)});
            return;
        }
    }
}

/// Create a new context for a specific global scope kind (BSCOPE-05)
///
/// This function creates a V8 context from the snapshot for the given scope,
/// sets up the runtime context with proper wrapper cache isolation, and
/// optionally links it to a parent context for iframe/worker hierarchies.
///
/// The created context will have:
/// - Interfaces filtered by [Exposed] attribute for the scope
/// - Its own isolated wrapper cache
/// - Proper realm with context_type matching the scope
/// - Parent-child relationship if parent is provided
///
/// Thread safety: Thread-local, no synchronization needed
///
/// Arguments:
/// - isolate: V8 isolate pointer
/// - scope_kind: The global scope kind to create context for
/// - parent: Optional parent context entry for hierarchical contexts
/// - allocator: Allocator for context resources
///
/// Returns: Pointer to the created ContextEntry, or error
pub fn createContext(
    isolate: *v8.Isolate,
    scope_kind: runtime.realm.GlobalScopeKind,
    parent: ?*ContextEntry,
    allocator: std.mem.Allocator,
) !*ContextEntry {
    const state = &(manager_state orelse return error.NotInitialized);

    // Create V8 context from snapshot for this scope
    const snapshot_loader = @import("snapshot_loader.zig");
    const v8_ctx = snapshot_loader.createContextForScope(isolate, scope_kind) orelse
        return error.ContextCreationFailed;

    // Get raw address for HashMap key (stable across Global/Local conversions)
    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse
        return error.ContextCreationFailed;
    const key = @intFromPtr(raw_addr);

    // Create the context entry
    const entry = try state.allocator.create(ContextEntry);
    errdefer state.allocator.destroy(entry);

    // Initialize runtime context
    var ctx_data = runtime.Context{
        .allocator = allocator,
        .arena = null,
        .v8_isolate = isolate,
        .v8_ctx = v8_ctx,
    };

    // Create isolated wrapper cache for this context
    const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
    const wrapper_cache = try allocator.create(WrapperCache);
    errdefer allocator.destroy(wrapper_cache);
    wrapper_cache.* = WrapperCache.init(allocator);
    ctx_data.setV8WrapperCacheStorage(wrapper_cache);

    // Map scope_kind to context_type for realm
    const context_type: runtime.realm.ContextType = switch (scope_kind) {
        .window => .window,
        .dedicated_worker => .dedicated_worker,
        .shared_worker => .shared_worker,
        .service_worker => .service_worker,
        .audio_worklet, .paint_worklet, .animation_worklet, .layout_worklet, .shared_storage_worklet => .worklet,
        .shadow_realm, .unknown => .unknown,
    };

    // Create realm with appropriate context type
    const realm_instance = try allocator.create(runtime.Realm);
    errdefer allocator.destroy(realm_instance);
    realm_instance.* = runtime.Realm.init(allocator, context_type);

    // Initialize entry
    entry.* = ContextEntry{
        .v8_ctx = v8_ctx,
        .runtime_ctx = ctx_data,
        .owns_context = true,
        .event_loop = null, // Will be set up separately if needed
        .realm = realm_instance,
        .parent_entry = parent,
        .children = .empty,
        .allocator = state.allocator,
    };

    // Link to parent if provided
    if (parent) |p| {
        try p.children.append(state.allocator, entry);
    }

    // Store in contexts HashMap
    try reserveRetirement(state);
    try state.contexts.put(key, entry);

    // Hydrate with scope-specific interfaces (already filtered by snapshot)
    // Note: Snapshot already contains only exposed interfaces, but we call
    // hydrateContextFromSnapshot for any additional runtime setup
    const helper_scope = snapshot_loader.SnapshotContextIndex.forScopeKind(scope_kind).toHelperScope();
    hydrateContextFromSnapshot(isolate, v8_ctx, helper_scope);

    return entry;
}

/// Register an existing runtime context for a V8 context
///
/// Use this when you have an existing runtime context that you want to associate
/// with a V8 context. The context manager will NOT own this context and will
/// NOT call deinit() on it.
///
/// Thread safety: Thread-local, no synchronization needed
///
/// Arguments:
/// - v8_ctx: V8 context pointer
/// - ctx: Existing runtime context (borrowed, not owned)
pub fn register(v8_ctx: *v8.Context, ctx: runtime.Context) !void {
    const state = &(manager_state orelse return error.NotInitialized);

    const key = @intFromPtr(v8_ctx);

    // Heap-allocate the entry so it doesn't move when HashMap rehashes
    const entry = try state.allocator.create(ContextEntry);
    errdefer state.allocator.destroy(entry);

    entry.* = ContextEntry{
        .v8_ctx = v8_ctx,
        .runtime_ctx = ctx.*, // Copy the context data
        .owns_context = false, // Don't deinit this one
        .event_loop = null, // Registered contexts don't have event loop
        .realm = null,
        .parent_entry = null,
        .children = .empty,
        .allocator = state.allocator,
    };

    // Store pointer in map - entry won't move even if HashMap rehashes
    try reserveRetirement(state);
    try state.contexts.put(key, entry);
}

/// Remove a runtime context for a V8 context
///
/// If the context manager owns the runtime context, it will be deinitialized.
/// If the context was registered via register(), it will NOT be deinitialized.
///
/// This function uses the cleanup coordinator to prevent GC callbacks from
/// firing during cleanup, which would cause crashes.
///
/// Thread safety: Thread-local, no synchronization needed
pub fn removeContext(v8_ctx: *v8.Context) void {
    // Use the raw V8 internal address as the key (must match getOrCreate*)
    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return;
    removeContextByKey(@intFromPtr(raw_addr), v8_ctx);
}

/// The key `removeContextByKey` takes for `v8_ctx` - read while the context
/// lives (it is in the context's embedder data), so a realm whose context
/// the collector may take first can still be removed.
pub fn keyOf(v8_ctx: *v8.Context) ?usize {
    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return null;
    return @intFromPtr(raw_addr);
}

/// `removeContext` by the context's key (`keyOf`): the realm's Window, its
/// wrapper cache and its realm record go, and the entry is retired. Touches
/// the context only through `v8_ctx`, which may be null - a context the
/// collector already took - when the entry knows its Window.
pub fn removeContextByKey(key: usize, v8_ctx: ?*v8.Context) void {
    const state = &(manager_state orelse return);
    const raw_addr: ?*anyopaque = @ptrFromInt(key);

    if (state.contexts.fetchRemove(key)) |kv| {
        const entry = kv.value; // This is now *ContextEntry
        // Retire rather than destroy: Instances created in this context are not
        // destroyed below (they go with the slab) and their `ctx` points into
        // this entry. See ManagerState.retired.
        defer retireEntry(state, entry);
        // First, while every object of the realm is alive: the promise
        // reactions that have not run and the asynchronous iterators still
        // alive end, and their host data with them (realm_finalizers.zig).
        if (@import("realm_finalizers.zig").listOf(&entry.runtime_ctx)) |finalizers| finalizers.drain();
        // The callbacks this context's script registered hold handles into it
        // - one listener is enough to keep the whole page alive - and nothing
        // else releases them, since its EventTargets are never torn down.
        @import("callback_registry.zig").cleanupForContext(raw_addr);
        if (entry.owns_context) {
            // A pointer, not a copy - `clearV8WrapperCacheStorage` below has to
            // land on the entry's own ContextData, which is what every Instance
            // in this context reads through.
            const ctx_data = &entry.runtime_ctx;
            const cleanup_coordinator = runtime.cleanup_coordinator;
            const WrapperCache = @import("wrapper_cache.zig").WrapperCache;

            // Create coordinator for this context teardown
            // This signals GC callbacks to skip, preventing crashes
            var coordinator = cleanup_coordinator.CleanupCoordinator.init(state.allocator);
            defer coordinator.deinit();

            // Set coordinator as active so GC callbacks can check teardown state
            cleanup_coordinator.setActiveCoordinator(&coordinator);
            defer cleanup_coordinator.setActiveCoordinator(null);

            // Begin coordinated cleanup - signals GC callbacks to skip
            coordinator.beginContextCleanup();

            // A frame's realm is made by engine.createWindowRealm with a
            // parent, whose end ends it first (protocol_realms): no entry
            // has children here.
            entry.children.deinit(entry.allocator);

            // Clean up Window and Document (DOM tree) before wrapper cache
            // This is critical: DOM nodes (including HTMLIFrameElement) need their
            // deinit called to clean up resources like BrowsingContext.
            // DOM nodes may not be in the wrapper_cache if never accessed from JS.
            // We must explicitly trigger DOM tree cleanup here.
            coordinator.cleanupPhase(.dom_tree);

            // NOTE: We do NOT iterate wrapper_cache to find HTMLIFrameElement instances.
            // Per Chromium's pattern, wrapper cache iteration is unsafe because:
            // 1. Some instances may have invalid state pointers
            // 2. Instance types cannot be safely checked without accessing state
            // Instead, we rely on DOM tree traversal: Window.deinit → Document.deinit →
            // Node.deinit chain which properly cleans up all DOM nodes including iframes.
            // HTMLIFrameElement instances are cleaned up when Node.deinit iterates children.

            // Clean up the Window and its DOM tree
            const window_instance_dom = entry.window_instance orelse if (v8_ctx) |c| getWindowFromGlobalInternalField(c) else null;
            if (window_instance_dom) |wi| {
                // Remove Window from wrapper cache FIRST to prevent double-free
                if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
                    const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
                    _ = cache_ptr.remove(wi);
                }

                // Also remove Location from wrapper cache before Window.deinit
                const WindowImpl = @import("impls").Window;
                if (WindowImpl.getInternal(wi)) |window_internal| {
                    if (window_internal.location) |loc| {
                        if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
                            const cache_ptr2: *WrapperCache = @ptrCast(@alignCast(cache_storage));
                            _ = cache_ptr2.remove(loc);
                        }
                    }
                }

                // Now call Window.deinit which will clean up Location, Document, and DOM tree
                WindowImpl.deinit(wi);
            }

            // Clean up V8 wrapper cache
            // Now safe because:
            // 1. Children are already cleaned up (no stale child pointers)
            // 2. DOM nodes already removed themselves
            // 3. HTMLIFrameElement instances explicitly cleaned up above
            coordinator.cleanupPhase(.wrapper_cache);
            if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
                const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
                cache_ptr.deinit();
                ctx_data.getAllocator().destroy(cache_ptr);
                ctx_data.clearV8WrapperCacheStorage();
            }

            // Clean up V8 event loop
            coordinator.cleanupPhase(.event_loop);
            if (entry.event_loop) |ev_loop| {
                ev_loop.deinit();
                ctx_data.getAllocator().destroy(ev_loop);
            }

            // Clean up realm
            if (entry.realm) |realm| {
                @import("realm_v8.zig").disposeIntrinsics(realm);
                realm.deinit();
            }

            // NOTE: no `ctx_data.deinit()` here - deinit()'s drain does it, once
            // no Instance can still be pointing at this ContextData.
        }

        entry.runtime_ctx.clearDocumentUrl();
    }
}

/// Set the default allocator to use for new contexts
///
/// This allocator will be used when creating new runtime contexts via getOrCreate()
/// if no specific allocator is provided.
pub fn setDefaultAllocator(allocator: std.mem.Allocator) !void {
    const state = &(manager_state orelse return error.NotInitialized);
    state.default_allocator = allocator;
}

/// Clear all wrapper caches without destroying the contexts
///
/// This is used for test isolation - clears cached V8 wrappers between tests
/// while keeping the contexts alive. This prevents stale V8 objects from
/// causing issues when running multiple tests sequentially.
///
/// The two-phase cleanup in WrapperCache.clear() ensures:
/// 1. All weak callbacks are disabled first (no use-after-free)
/// 2. Then instances are cleaned up via GC integration (type-specific deinit)
/// 3. V8 handles are disposed
/// 4. CacheEntries are freed
///
/// Thread safety: Thread-local, no synchronization needed
pub fn clearWrapperCaches() void {
    const state = &(manager_state orelse return);
    const WrapperCache = @import("wrapper_cache.zig").WrapperCache;

    var it = state.contexts.valueIterator();
    while (it.next()) |entry_ptr| {
        const entry = entry_ptr.*; // Dereference pointer to get *ContextEntry
        var ctx_data = entry.runtime_ctx;
        if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
            const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
            cache_ptr.clear();
        }
    }
}

// ============================================================================
// Child Context Management (Cross-Realm Support)
// ============================================================================

/// Create a Window instance bound to the V8 global object
///
/// This is the key function for cross-realm support. Instead of creating a
/// separate V8 wrapper for the Window, we bind the Window instance directly
/// to the V8 global object. This ensures that:
///
/// 1. `iframe.contentWindow` returns the V8 global (which has DOMRectReadOnly, etc.)
/// 2. `iframe.contentWindow === iframe.contentWindow.window` is true
/// 3. Cross-realm tests like `default-toJSON-cross-realm.html` work correctly
///
/// The binding works by:
/// 1. Creating a Window runtime.Instance
/// 2. Setting the V8 global's internal fields to point to the Window instance
/// 3. Caching the V8 global as the wrapper for the Window instance
fn createWindowBoundToGlobal(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    v8_ctx: *v8.Context,
    isolate: *v8.Isolate,
) !*runtime.Instance {
    const interfaces = @import("interfaces");
    const Window = interfaces.Window;
    const WindowImpl = @import("impls").Window;
    const WrapperCache = @import("wrapper_cache.zig").WrapperCache;

    // 1. Create Window instance
    const window_instance = try Window.init(allocator, ctx);
    errdefer Window.deinit(window_instance);

    // 2. Get the V8 global object
    const global = v8.v8_Context_Global(v8_ctx) orelse return error.GlobalNotFound;

    // 3. Set internal fields on the global to point to our Window instance
    // Field 0: instance pointer
    // Field 1: type info pointer (for type-safe unwrapping)
    v8.v8_Object_SetAlignedPointerInInternalField(
        global,
        0,
        @ptrCast(window_instance),
    );

    // Use dom_type_info which has the actual type info definitions
    const dom_type_info = @import("dom_type_info.zig");
    if (dom_type_info.getTypeInfoByName("Window")) |type_info| {
        v8.v8_Object_SetAlignedPointerInInternalField(
            global,
            1,
            @ptrCast(@constCast(type_info)),
        );
    }

    // 4. Store the V8 global in the Window's internal state
    // This is the KEY change for cross-realm support:
    // When instanceToV8 is called on this Window, it returns this global
    // directly instead of creating a new wrapper. This makes
    // `iframe.contentWindow.DOMRectReadOnly` work correctly.
    WindowImpl.setBoundV8Global(window_instance, @ptrCast(global));

    // 5. Set this Window as the active window of its browsing context
    // Per HTML spec §7.4, every browsing context has an "active window" which is the
    // Window object of its active document. This is required for frames[index] access
    // to work, since WindowProxy [[GetOwnProperty]] calls getActiveWindow().
    if (WindowImpl.getInternal(window_instance)) |internal| {
        internal.browsing_context.setActiveWindow(@ptrCast(window_instance));
    }

    // 6. Also cache the V8 global as the wrapper for this Window instance
    // This is for consistency with the wrapper cache system
    if (ctx.getV8WrapperCacheStorage()) |cache_storage| {
        const cache: *WrapperCache = @ptrCast(@alignCast(cache_storage));
        try cache.set(window_instance, global, isolate);
    }

    // 7. Set up Window-specific global properties (window, self, globalThis)
    // Per HTML spec, browsers expose these properties on the global object:
    // - 'window' references the global Window object
    // - 'self' references the global object (works in both window and worker contexts)
    // - 'globalThis' is the standard reference to the global object
    const window_key = v8.v8_String_NewFromUtf8(isolate, "window", 6) orelse return error.StringCreationFailed;
    defer v8.v8_String_Dispose(window_key);
    _ = v8.v8_Object_Set(global, v8_ctx, @ptrCast(window_key), @ptrCast(global));

    // `self` is [Replaceable]: its setter's one step is this [[DefineOwnProperty]]
    // (writable, enumerable, configurable), so define it directly. A [[Set]]
    // went through the script-facing setter, whose argument handle - here a
    // handle to the WindowProxy - is never released, and a leaked handle to a
    // frame's WindowProxy kept its realm, and through the realm's security
    // token its parent page, alive after the frame was gone.
    const self_key = v8.v8_String_NewFromUtf8(isolate, "self", 4) orelse return error.StringCreationFailed;
    defer v8.v8_String_Dispose(self_key);
    _ = v8.v8_Object_DefineProperty(global, v8_ctx, @ptrCast(self_key), @ptrCast(global), true, true, true);

    const global_this_key = v8.v8_String_NewFromUtf8(isolate, "globalThis", 10) orelse return error.StringCreationFailed;
    defer v8.v8_String_Dispose(global_this_key);
    _ = v8.v8_Object_Set(global, v8_ctx, @ptrCast(global_this_key), @ptrCast(global));

    return window_instance;
}

// ============================================================================
// Iframe Document Initialization
// ============================================================================

/// Initialize an iframe document with the standard HTML structure.
///
/// Per HTML spec, a new browsing context's document should be initialized with:
/// ```html
/// <!DOCTYPE html>
/// <html>
///   <head></head>
///   <body></body>
/// </html>
/// ```
///
/// This ensures that `document.body`, `document.head`, and `document.documentElement`
/// are all properly set for iframe documents.
fn initializeIframeDocumentStructure(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    document: *runtime.Instance,
) void {
    const interfaces = @import("interfaces");
    const impls = @import("impls");
    const DocumentImpl = impls.Document;
    const ElementImpl = impls.Element;

    // Set document type to HTML (required for proper body/head detection)
    DocumentImpl.setDocumentType(document, .html) catch return;

    // Set content type
    DocumentImpl.setContentType(document, "text/html") catch return;

    // Create <html> element
    const html_element = interfaces.HTMLHtmlElement.init(allocator, ctx) catch return;
    ElementImpl.setLocalName(html_element, "html") catch {
        interfaces.HTMLHtmlElement.deinit(html_element);
        return;
    };
    node_document.set(html_element, document) catch {
        interfaces.HTMLHtmlElement.deinit(html_element);
        return;
    };

    // Append html to document
    _ = interfaces.Node.call_appendChild(document, html_element) catch {
        interfaces.HTMLHtmlElement.deinit(html_element);
        return;
    };

    // Set as document element (direct access to internal state)
    if (DocumentImpl.getInternal(document)) |doc_internal| {
        doc_internal.document_element = html_element;
    }

    // Create <head> element
    const head_element = interfaces.HTMLHeadElement.init(allocator, ctx) catch return;
    ElementImpl.setLocalName(head_element, "head") catch {
        interfaces.HTMLHeadElement.deinit(head_element);
        return;
    };
    node_document.set(head_element, document) catch {
        interfaces.HTMLHeadElement.deinit(head_element);
        return;
    };

    // Append head to html
    _ = interfaces.Node.call_appendChild(html_element, head_element) catch {
        interfaces.HTMLHeadElement.deinit(head_element);
        return;
    };

    // Create <body> element
    const body_element = interfaces.HTMLBodyElement.init(allocator, ctx) catch return;
    ElementImpl.setLocalName(body_element, "body") catch {
        interfaces.HTMLBodyElement.deinit(body_element);
        return;
    };
    node_document.set(body_element, document) catch {
        interfaces.HTMLBodyElement.deinit(body_element);
        return;
    };

    // Append body to html
    _ = interfaces.Node.call_appendChild(html_element, body_element) catch {
        interfaces.HTMLBodyElement.deinit(body_element);
        return;
    };
}

// ============================================================================
// Window Indexed Property Handler for frames[index] access
// ============================================================================

/// Indexed property getter for Window global objects.
/// Enables `window.frames[0]`, `window[0]`, etc. to access child browsing contexts.
///
/// Per HTML spec §7.4.3.1 (WindowProxy [[GetOwnProperty]]):
/// - Numeric indices return the corresponding child browsing context's Window
/// - Returns undefined if index >= children.length
///
/// This callback is registered on the global object template for child contexts.
///
/// IMPORTANT: This function handles lazy initialization of child browsing contexts.
/// When an iframe is inserted into the DOM, a BrowsingContext is created but the
/// V8 context and Window instance are NOT created until needed. This getter triggers
/// the creation of the V8 child context when frames[index] is accessed and the
/// child browsing context exists but doesn't have an active Window yet.
pub fn windowIndexedPropertyGetter(
    index: u32,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    const WindowImpl = @import("impls").Window;
    const template_registry = @import("template_registry.zig");
    const conv = @import("conversions.zig");

    const isolate = info.getIsolate();
    const v8_context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return .kNo;

    // Get the 'this' object (the global/Window object)
    const this_obj = info.getThis();
    defer v8.v8_Object_Dispose(this_obj);

    // Also try getting the global from the context (might be different from this_obj)
    const global_obj = v8.v8_Context_Global(v8_context);

    // Extract instance pointer from internal field
    var instance_ptr = v8.v8_Object_GetAlignedPointerFromInternalField(this_obj, 0);

    // If this_obj doesn't have internal fields, try global_obj
    if (instance_ptr == null and global_obj != null) {
        instance_ptr = v8.v8_Object_GetAlignedPointerFromInternalField(global_obj.?, 0);
    }

    if (instance_ptr == null) {
        // No instance - let V8 handle normal lookup
        return .kNo;
    }

    // Safety check for use-after-free patterns
    const ptr_as_int = @intFromPtr(instance_ptr);
    const poison_pattern_aa: usize = 0xaaaaaaaaaaaaaaaa;
    const poison_pattern_dead: usize = 0xdeaddeaddeaddead;
    if (ptr_as_int == poison_pattern_aa or ptr_as_int == poison_pattern_dead or
        (ptr_as_int & 0xFFFF000000000000) == 0xaaaa000000000000)
    {
        return .kNo;
    }

    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));

    // First try to get an existing child Window via Window.call_item
    var result = WindowImpl.call_item(instance, index) catch {
        // Error - let V8 handle normal lookup
        return .kNo;
    };

    // If result is null, check if we need to lazily create the child context
    // This happens when an iframe is in the DOM but contentWindow hasn't been accessed yet
    if (result == null) {
        const internal = WindowImpl.getInternal(instance) orelse return .kNo;

        // First check if a browsing context exists at this index
        const children = internal.browsing_context.children.items;
        if (index < children.len) {
            const child_bc = children[index];

            // Child browsing context exists but no Window: its container
            // makes its navigable's realm (engine.createWindowRealm with this
            // window's realm as the parent), Window and initial document.
            if (child_bc.getActiveWindow() == null) {
                result = @import("dom").child_navigables.window(@ptrCast(child_bc));
            }
        } else {
            // No browsing context exists yet - the iframe hasn't had its browsing context
            // initialized. This can happen if the iframe was created in JavaScript and
            // frames[index] is accessed before contentWindow was accessed on the iframe.
            //
            // To handle this, we need to:
            // 1. Find the Nth iframe element in the document
            // 2. Trigger its contentWindow creation (which initializes its browsing context)
            // 3. Retry the lookup
            //
            // We can access the document via the Window instance and enumerate iframes.
            const HTMLIFrameElementImpl = @import("impls").HTMLIFrameElement;
            const interfaces = @import("interfaces");

            // Try to get the document from Window's internal state first
            var doc: ?*runtime.Instance = internal.document;

            // If no document yet, try to get it via the Window.document getter
            // This works because the document is set on the global object even during parsing
            if (doc == null) {
                doc = WindowImpl.get_document(instance) catch null;
            }

            if (doc) |document| {
                // Get all iframe elements using getElementsByTagName
                const iframe_tag = runtime.DOMString.initInterned("iframe");
                const iframes = interfaces.Document.call_getElementsByTagName(document, iframe_tag) catch {
                    return .kNo; // Can't access iframes
                };

                // Check if we have enough iframes in the DOM
                const iframe_count = interfaces.HTMLCollection.get_length(iframes) catch 0;
                if (index < iframe_count) {
                    // Get the Nth iframe and access its contentWindow to trigger initialization
                    if (interfaces.HTMLCollection.call_item(iframes, index) catch null) |iframe_elem| {
                        // This call triggers IFrameIntegration.ensureBrowsingContext
                        _ = HTMLIFrameElementImpl.get_contentWindow(iframe_elem) catch null;

                        // Now retry - the child should exist
                        result = WindowImpl.call_item(instance, index) catch null;
                    }
                }
            }
        }
    }

    if (result) |child_window| {
        // We have a child Window instance - wrap it and return
        const interface_name = template_registry.getInstanceInterfaceName(child_window);
        const wrapped = template_registry.wrapInstanceAsV8Object(
            child_window,
            interface_name,
            isolate,
            v8_context,
        ) catch {
            conv.throwError(isolate, "Failed to wrap child window");
            return .kNo;
        };
        info.setReturnValue(@ptrCast(wrapped));
        return .kYes;
    }
    // If result is null (out of bounds), don't set a return value
    // This lets V8 continue with normal property lookup (returns undefined)
    return .kNo;
}

/// Indexed property query for Window global objects.
/// Returns PropertyAttribute flags if the index is a valid frame index.
/// Per V8 IndexedPropertyQueryCallback:
/// - Return Intercepted.kYes if property exists (with attributes set via info.setReturnValue)
/// - Return Intercepted.kNo if property doesn't exist (continue normal lookup)
pub fn windowIndexedPropertyQuery(
    index: u32,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    const this_obj = info.getThis();
    defer v8.v8_Object_Dispose(this_obj);
    const instance_ptr = v8.v8_Object_GetAlignedPointerFromInternalField(this_obj, 0);
    if (instance_ptr == null) return .kNo;

    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));

    // Check if this index is valid
    const length = @import("interfaces").Window.get_length(instance) catch return .kNo;
    if (index < length) {
        // Valid index - return property attributes (ReadOnly | DontEnum)
        // Per spec, indexed properties on Window are configurable but not writable
        const isolate = info.getIsolate();
        const attrs = v8.v8_Integer_New(isolate, 3); // 3 = ReadOnly | DontEnum
        // SetReturnValue copies; the Global is ours.
        defer v8.v8_Value_Dispose(@ptrCast(attrs));
        info.setReturnValue(@ptrCast(attrs));
        return .kYes;
    }
    // Invalid index - property doesn't exist
    return .kNo;
}

/// Indexed property enumerator for Window global objects.
/// Returns an array of indices 0..length-1.
pub fn windowIndexedPropertyEnumerator(
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) void {
    const isolate = info.getIsolate();

    // Every handle below is this callback's: SetReturnValue and Array::Set
    // copy what they are given. Kept, they were two Globals per enumeration
    // of the window's own keys - the context and the array - and one more per
    // child navigable.
    const this_obj = info.getThis();
    defer v8.v8_Object_Dispose(this_obj);
    const instance_ptr = v8.v8_Object_GetAlignedPointerFromInternalField(this_obj, 0);
    const length: u32 = if (instance_ptr) |ptr| blk: {
        const instance: *runtime.Instance = @ptrCast(@alignCast(ptr));
        break :blk @import("interfaces").Window.get_length(instance) catch 0;
    } else 0;

    // Create array of indices as integers
    // V8's indexed property interceptor expects integer indices here.
    // V8 internally converts these to strings when needed for ownKeys.
    const arr = v8.v8_Array_New(isolate, @intCast(length));
    defer v8.v8_Array_Dispose(arr);
    if (length > 0) {
        const v8_context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
        defer v8.v8_Context_Dispose(v8_context);
        var i: u32 = 0;
        while (i < length) : (i += 1) {
            const idx_val = v8.v8_Integer_New(isolate, @intCast(i));
            defer v8.v8_Value_Dispose(@ptrCast(idx_val));
            _ = v8.v8_Array_Set(arr, v8_context, i, @ptrCast(idx_val));
        }
    }
    info.setReturnValue(@ptrCast(arr));
}

// ============================================================================
// Named Property Handlers for Window Global Objects
// ============================================================================
//
// Per HTML spec §7.4.3 (Named access on the Window object), the Window object
// supports named property access for:
// 1. Child browsing contexts (iframe names) - frames['name'] returns contentWindow
// 2. Named elements in the document (elements with id/name attributes)
//
// These handlers are installed on the global object template during snapshot creation
// to enable frames['name'] access directly on the window object.
// ============================================================================

/// Named property getter for Window global objects.
/// Returns child browsing context windows by name, or named document elements.
///
/// When JavaScript accesses window['someName'] or window.frames['someName']:
/// 1. First checks child browsing contexts by target_name (iframe name attribute)
/// 2. Falls back to named elements in the document
///
/// This handler is registered on the Window global template and intercepts all
/// string property accesses that don't match built-in properties.
pub fn windowNamedPropertyGetter(
    property: *v8.Name,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    const WindowImpl = @import("impls").Window;
    const conv = @import("conversions.zig");

    const isolate = info.getIsolate();
    const v8_context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return .kNo;

    // Convert property name to Zig string
    var name_buf: [256]u8 = undefined;
    const name = nameToNative(isolate, property, &name_buf) orelse return .kNo;

    // Skip built-in property names to avoid intercepting them
    // These are common properties that should fall through to normal lookup
    if (isBuiltinWindowProperty(name)) {
        return .kNo;
    }

    // Get the Window instance from the global object
    const this_obj = info.getThis();
    defer v8.v8_Object_Dispose(this_obj);
    var instance_ptr = v8.v8_Object_GetAlignedPointerFromInternalField(this_obj, 0);

    // If this_obj doesn't have internal fields, try the global object
    if (instance_ptr == null) {
        const global_obj = v8.v8_Context_Global(v8_context);
        if (global_obj) |global| {
            instance_ptr = v8.v8_Object_GetAlignedPointerFromInternalField(global, 0);
        }
    }

    if (instance_ptr == null) {
        return .kNo;
    }

    // Safety check for use-after-free patterns
    const ptr_as_int = @intFromPtr(instance_ptr);
    const poison_pattern_aa: usize = 0xaaaaaaaaaaaaaaaa;
    const poison_pattern_dead: usize = 0xdeaddeaddeaddead;
    if (ptr_as_int == poison_pattern_aa or ptr_as_int == poison_pattern_dead or
        (ptr_as_int & 0xFFFF000000000000) == 0xaaaa000000000000)
    {
        return .kNo;
    }

    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));

    // Call Window.getNamedProperty which checks:
    // 1. Child browsing context names (iframe name attributes)
    // 2. Named elements in the document
    const result = WindowImpl.getNamedProperty(instance, name) catch return .kNo;

    if (result) |js_val| {
        const value = conv.toV8Value(runtime.JSValue, isolate, v8_context, js_val) catch return .kNo;
        info.setReturnValue(value);
        return .kYes;
    }

    // Property not found - let V8 continue with normal lookup
    return .kNo;
}

/// Named property query for Window global objects.
/// Returns whether a named property exists.
pub fn windowNamedPropertyQuery(
    property: *v8.Name,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    const WindowImpl = @import("impls").Window;

    const isolate = info.getIsolate();
    const v8_context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return .kNo;

    // Convert property name to Zig string
    var name_buf: [256]u8 = undefined;
    const name = nameToNative(isolate, property, &name_buf) orelse return .kNo;

    // Skip built-in property names
    if (isBuiltinWindowProperty(name)) {
        return .kNo;
    }

    // Get Window instance
    const this_obj = info.getThis();
    defer v8.v8_Object_Dispose(this_obj);
    var instance_ptr = v8.v8_Object_GetAlignedPointerFromInternalField(this_obj, 0);

    if (instance_ptr == null) {
        const global_obj = v8.v8_Context_Global(v8_context);
        if (global_obj) |global| {
            instance_ptr = v8.v8_Object_GetAlignedPointerFromInternalField(global, 0);
        }
    }

    if (instance_ptr == null) {
        return .kNo;
    }

    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));

    // Check if property exists
    if (WindowImpl.hasNamedProperty(instance, name)) {
        // Property exists - return attributes (ReadOnly | DontEnum)
        const attrs = v8.v8_Integer_New(isolate, 3); // 3 = ReadOnly | DontEnum
        info.setReturnValue(@ptrCast(attrs));
        return .kYes;
    }

    return .kNo;
}

/// Convert a V8 Name to a native Zig string
fn nameToNative(_: *v8.Isolate, name: *v8.Name, buf: []u8) ?[]const u8 {
    return @import("helpers.zig").nameToUtf8(name, buf);
}

/// Check if a property name is a built-in Window property that should not be intercepted.
/// This avoids intercepting normal property access like window.document, window.location, etc.
fn isBuiltinWindowProperty(name: []const u8) bool {
    // List of common Window properties that should not be intercepted
    const builtins = [_][]const u8{
        // Core Window properties
        "window",         "self",                  "document",             "location",           "navigator",            "history",                   "screen",
        "frames",         "length",                "top",                  "parent",             "opener",               "frameElement",              "name",
        // Common methods
        "alert",          "confirm",               "prompt",               "open",               "close",                "focus",                     "blur",
        "postMessage",    "addEventListener",      "removeEventListener",  "dispatchEvent",      "setTimeout",           "clearTimeout",              "setInterval",
        "clearInterval",  "requestAnimationFrame", "cancelAnimationFrame",
        // Constructors and built-in objects
        "Object",             "Array",                "Function",                  "String",
        "Number",         "Boolean",               "Symbol",               "Error",              "TypeError",            "ReferenceError",            "SyntaxError",
        "RangeError",     "Promise",               "Map",                  "Set",                "WeakMap",              "WeakSet",                   "Proxy",
        "Reflect",        "JSON",                  "Math",                 "Date",               "RegExp",               "console",                   "Intl",
        // DOM interfaces
        "Node",           "Element",               "Document",             "Event",              "EventTarget",          "HTMLElement",               "HTMLIFrameElement",
        "HTMLDivElement", "HTMLSpanElement",       "HTMLCollection",       "NodeList",           "DOMTokenList",         "CSSStyleDeclaration",
        // Other common properties
              "undefined",
        "null",           "NaN",                   "Infinity",             "eval",               "isNaN",                "isFinite",                  "parseInt",
        "parseFloat",     "encodeURI",             "decodeURI",            "encodeURIComponent", "decodeURIComponent",   "performance",               "crypto",
        "fetch",          "URL",                   "URLSearchParams",      "FormData",           "Blob",                 "File",                      "FileReader",
        "FileList",       "ArrayBuffer",           "DataView",             "Uint8Array",         "Uint16Array",          "Uint32Array",               "Int8Array",
        "Int16Array",     "Int32Array",            "Float32Array",         "Float64Array",       "BigInt64Array",        "BigUint64Array",            "WebSocket",
        "Worker",         "MessageChannel",        "MessagePort",          "MutationObserver",   "IntersectionObserver", "IntersectionObserverEntry", "ResizeObserver",
    };

    for (builtins) |builtin| {
        if (std.mem.eql(u8, name, builtin)) {
            return true;
        }
    }

    return false;
}

/// Take an entry out of service without freeing it.
///
/// See `ManagerState.retired`: an Instance's `ctx` is a pointer INTO this entry,
/// and the Instances outlive the entry. What can be released has been released by
/// the caller; this makes the ContextData inert so that a stale `ctx` answers
/// "no wrapper cache, no engine context, no realm" rather than reading poison.
///
/// `engine` is left alone on purpose - it points at a static interface, and
/// `ContextData.deinit` needs it to release `_engine_event_loop_storage`.
fn retireEntry(state: *ManagerState, entry: *ContextEntry) void {
    // The entry's own handle was the last strong root of a destroyed frame:
    // everything else that held the page is released by now, so every frame
    // ever torn down kept its whole heap - context, global, wrappers - alive
    // for the rest of the process. Nothing reads a retired entry's context:
    // the map no longer finds it, destroyChildContext returns at `destroying`,
    // and the drain in deinit frees only Zig state.
    if (entry.owns_v8_ctx) {
        v8.v8_Context_Dispose(entry.v8_ctx);
        entry.owns_v8_ctx = false;
    }
    entry.runtime_ctx.clearV8WrapperCacheStorage();
    entry.runtime_ctx.engine_ctx = null;
    entry.runtime_ctx.realm = null;
    entry.runtime_ctx.event_loop = null;
    entry.runtime_ctx.timer = null;
    entry.children = .empty;
    entry.parent_entry = null;
    entry.window_instance = null;
    entry.runtime_ctx.clearDocumentUrl();

    // Never allocates: every entry reserved its slot before it went into
    // `contexts` (reserveRetirement). The old fallback - freeing the entry when
    // this append ran out of memory - left every Context kept across turns
    // pointing at freed memory, where engine_protocol.zig's Context contract
    // promises a valid, inert record until the agent ends.
    state.retired.appendAssumeCapacity(entry);
}

/// Reserve the `retired` slot an entry about to go into `contexts` will take
/// when it is retired, so that retireEntry never allocates: capacity stays at
/// least every retired entry plus every live one. Called before each insert;
/// out of memory here fails the realm's creation, never its retirement.
fn reserveRetirement(state: *ManagerState) error{OutOfMemory}!void {
    try state.retired.ensureTotalCapacity(state.allocator, state.retired.items.len + state.contexts.count() + 1);
}

/// Get the realm for a V8 context
///
/// Returns the Realm associated with the given V8 context, or null
/// if no realm is associated or the context is not registered.
///
/// Thread safety: Thread-local, no synchronization needed
pub fn getRealmForContext(v8_ctx: *v8.Context) ?*runtime.Realm {
    const state = &(manager_state orelse return null);

    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return null;
    const key = @intFromPtr(raw_addr);

    if (state.contexts.get(key)) |entry| {
        return entry.realm;
    }

    return null;
}

/// Get the realm for the current V8 context
///
/// Returns the Realm for the currently entered V8 context, or null
/// if no context is entered or no realm is associated.
///
/// Thread safety: Thread-local, no synchronization needed
pub fn getCurrentRealm() ?*runtime.Realm {
    const isolate = v8.v8_Isolate_GetCurrent() orelse return null;
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return null;
    return getRealmForContext(context);
}

/// Get the ContextEntry for a V8 context
///
/// Returns the full ContextEntry for the given V8 context, allowing
/// access to parent/child relationships.
///
/// Thread safety: Thread-local, no synchronization needed
pub fn getEntry(v8_ctx: *v8.Context) ?*ContextEntry {
    const state = &(manager_state orelse return null);

    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return null;
    const key = @intFromPtr(raw_addr);

    return state.contexts.get(key);
}

/// Get the Window instance for a V8 context
///
/// Returns the Window *runtime.Instance that IS the V8 global object.
/// This is used by HTMLIFrameElement.get_contentWindow to return the
/// correct Window for cross-realm access.
///
/// For browser contexts created outside context_manager (e.g., main browser context),
/// falls back to getting the Window from the global object's internal field 0,
/// following the Chromium pattern where Window is stored in the global's internal field.
///
/// Thread safety: Thread-local, no synchronization needed
pub fn getWindowForContext(v8_ctx: *v8.Context) ?*runtime.Instance {
    // First check contexts managed by context_manager
    if (manager_state) |*state| {
        const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse {
            // Fallback to getting Window from global's internal field
            return getWindowFromGlobalInternalField(v8_ctx);
        };
        const key = @intFromPtr(raw_addr);

        if (state.contexts.get(key)) |entry| {
            // Return window_instance if it's set
            if (entry.window_instance) |window| {
                return window;
            }
            // Entry exists but window_instance is null - fallback to internal field
            return getWindowFromGlobalInternalField(v8_ctx);
        }
    }

    // Context not registered - fallback to getting Window from global's internal field
    // This handles Browser contexts created via Context.zig which store Window in internal field 0
    return getWindowFromGlobalInternalField(v8_ctx);
}

/// Helper to get Window from V8 global's internal field 0.
/// This follows the Chromium pattern where Window instance is stored in the
/// global object's internal field.
fn getWindowFromGlobalInternalField(v8_ctx: *v8.Context) ?*runtime.Instance {
    const global = v8.v8_Context_Global(v8_ctx) orelse return null;
    defer v8.v8_Object_Dispose(global);
    const ptr = v8.v8_Object_GetAlignedPointerFromInternalField(global, 0) orelse return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(ptr));
    // Field 0 of a worker's global holds its WorkerGlobalScope; only a Window
    // answers here. Callers read the result as a Window and removeContext
    // deinits it as one.
    if (instance.stateAs(@import("interfaces").Window.State) == null) return null;
    return instance;
}

/// Get the V8EventLoop for a V8 context
///
/// Returns the V8EventLoop associated with this context, if one was created.
/// This is used by worker threads to poll libuv timers (setTimeout/setInterval).
///
/// Thread safety: Thread-local, no synchronization needed
pub fn getEventLoop(v8_ctx: *v8.Context) ?*V8EventLoop {
    const state = &(manager_state orelse return null);

    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return null;
    const key = @intFromPtr(raw_addr);

    if (state.contexts.get(key)) |entry| {
        return entry.event_loop;
    }
    return null;
}

/// Associate a realm with an existing context
///
/// This is used when a context was created via getOrCreate but a realm
/// needs to be associated with it later.
///
/// Thread safety: Thread-local, no synchronization needed
pub fn setRealmForContext(v8_ctx: *v8.Context, realm: *runtime.Realm) !void {
    const state = &(manager_state orelse return error.NotInitialized);

    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return error.InvalidContext;
    const key = @intFromPtr(raw_addr);

    if (state.contexts.get(key)) |entry| {
        // Free existing realm if any
        if (entry.realm) |old_realm| {
            old_realm.deinit();
        }
        entry.realm = realm;
    } else {
        return error.ContextNotFound;
    }
}

/// Associate a Window instance with an existing context
///
/// This is used when Browser.Context creates its own Window instance
/// and needs to register it with the context manager so that
/// getWindowForContext() can find it later.
///
/// This is critical for iframe browsing context creation, where
/// handleIframeInsertion needs to look up the parent Window.
///
/// Thread safety: Thread-local, no synchronization needed
pub fn setWindowForContext(v8_ctx: *v8.Context, window: *runtime.Instance) !void {
    const state = &(manager_state orelse return error.NotInitialized);

    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return error.InvalidContext;
    const key = @intFromPtr(raw_addr);

    if (state.contexts.get(key)) |entry| {
        entry.window_instance = window;
    } else {
        return error.ContextNotFound;
    }
}

/// Set the document URL for a context (used for module resolution)
///
/// This should be called when navigating to a page to enable proper
/// resolution of relative module specifiers in dynamic imports.
pub fn setDocumentUrl(v8_ctx: *v8.Context, url: []const u8) !void {
    const state = &(manager_state orelse return error.NotInitialized);

    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return error.InvalidContext;
    const key = @intFromPtr(raw_addr);

    if (state.contexts.get(key)) |entry| {
        // The realm keeps it: runtime.ContextData.setDocumentUrl, which code
        // outside the adapter calls directly.
        try entry.runtime_ctx.setDocumentUrl(url);
    } else {
        return error.ContextNotFound;
    }
}

/// Get the document URL for a context
pub fn getDocumentUrl(v8_ctx: *v8.Context) ?[]const u8 {
    const state = manager_state orelse return null;

    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return null;
    const key = @intFromPtr(raw_addr);

    if (state.contexts.get(key)) |entry| {
        return entry.runtime_ctx.documentUrl();
    }
    return null;
}

/// Mark an instance as cleaned up in the wrapper cache
///
/// This should be called when a DOM node is being cleaned up via Node.deinit
/// to prevent double-free when the context is later torn down. The instance
/// has already been (or is being) cleaned up, so we mark it to prevent
/// wrapper_cache.deinit() from calling onObjectFreed again.
///
/// We don't remove from cache or dispose V8 handles here because we might
/// still be in JavaScript execution context. That happens in wrapper_cache.deinit().
///
/// Thread safety: Thread-local, no synchronization needed
pub fn markInstanceCleanedUp(instance: *runtime.Instance) void {
    // Get the context from the instance
    const ctx_data = instance.ctx;

    // Get the wrapper cache from the context
    const cache_storage = ctx_data.getV8WrapperCacheStorage() orelse return;
    const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
    const cache: *WrapperCache = @ptrCast(@alignCast(cache_storage));

    // Mark the instance as already cleaned up
    _ = cache.markAsCleanedUp(instance);
}

// ============================================================================
// External Reference Registration for V8 Snapshots
// ============================================================================

/// Register Window indexed property callbacks as external references
///
/// This MUST be called before creating or loading a V8 snapshot.
/// Indexed property callbacks must be registered so V8 can resolve them at load time.
pub fn registerExternalReferences() void {
    const ext_refs = @import("external_references.zig");

    // Register indexed property handler callbacks for Window global objects
    ext_refs.registerPointer(@intFromPtr(&windowIndexedPropertyGetter));
    ext_refs.registerPointer(@intFromPtr(&windowIndexedPropertyQuery));
    ext_refs.registerPointer(@intFromPtr(&windowIndexedPropertyEnumerator));

    // Register named property handler callbacks for Window global objects
    // These enable window.frames['name'] and window['elementId'] access
    ext_refs.registerPointer(@intFromPtr(&windowNamedPropertyGetter));
    ext_refs.registerPointer(@intFromPtr(&windowNamedPropertyQuery));
}

// ============================================================================
// Centralized Runtime Hydration API
// ============================================================================
//
// These functions centralize post-snapshot steps (template registry population,
// accessor reinstall, namespace registration, prototype fixes) into single
// per-context-type hydration functions.
//
// This eliminates duplication between Context.zig and worker_v8_context.zig.
// ============================================================================

/// Context type for hydration
pub const HydrationContextType = enum {
    /// Window context (for HTML pages) - gets document, location, navigator
    window,
    /// Worker context - gets self, postMessage (NO document, location)
    worker,
};

/// Options for hydrating a context
pub const HydrationOptions = struct {
    /// V8 isolate
    isolate: *v8.Isolate,
    /// V8 context to hydrate
    context: *v8.Context,
    /// Allocator for runtime objects
    allocator: std.mem.Allocator,
    /// Timer interface for setTimeout/setInterval
    timer_interface: ?runtime.TimerInterface = null,
    /// Event loop interface (streams EventLoop interface)
    event_loop_interface: ?@import("event_loop").EventLoop = null,
    /// Network manager for async fetch (Window only)
    network_manager: ?*anyopaque = null,
};

/// Hydration result containing created instances
pub const WindowHydrationResult = struct {
    /// Runtime context for the V8 context
    runtime_ctx: runtime.Context,
    /// Created Window instance
    window_instance: *runtime.Instance,
    /// Whether hydration succeeded
    success: bool = true,
};

/// Hydration result for worker contexts
pub const WorkerHydrationResult = struct {
    /// Runtime context for the V8 context
    runtime_ctx: runtime.Context,
    /// Whether hydration succeeded
    success: bool = true,
};

/// Hydrate a V8 context as a Window context (from snapshot)
///
/// This function performs all post-snapshot hydration steps for Window contexts:
/// 1. Populates Zig-side template registry (wrapInstanceAsV8Object support)
/// 2. Reinstalls accessor callbacks on prototypes (stale after snapshot load)
/// 3. Registers namespaces (console, WebAssembly, etc.)
/// 4. Sets up Window prototype chain on global
/// 5. Creates and binds Window instance to global object's internal fields
/// 6. Registers Window with context manager for cross-realm support
/// 7. Registers browser globals (document, navigator, location, etc.)
/// 8. Attaches event loop for setTimeout/setInterval
///
/// ## Usage
///
/// ```zig
/// const result = try context_manager.hydrateWindowContext(.{
///     .isolate = isolate,
///     .context = v8_ctx,
///     .allocator = allocator,
///     .timer_interface = event_loop.timerInterface(),
///     .event_loop_interface = event_loop.eventLoop(),
///     .namespaces_module = namespaces,
/// });
/// const window = result.window_instance;
/// ```
pub fn hydrateWindowContext(comptime namespaces_module: type, options: HydrationOptions) !WindowHydrationResult {
    const interface_bindings = @import("interface_bindings.zig");
    const interfaces = @import("interfaces");
    const impls = @import("impls");
    const WrapperCache = @import("wrapper_cache.zig").WrapperCache;

    const isolate = options.isolate;
    const v8_ctx = options.context;
    const allocator = options.allocator;

    // 1. Initialize context manager (if not already initialized)
    init(allocator) catch |err| {
        if (err != error.AlreadyInitialized) {
            return err;
        }
    };

    // 2. Register context with context manager for wrapper caching
    const runtime_ctx = try getOrCreateWithExternalEventLoop(
        v8_ctx,
        options.timer_interface,
        options.event_loop_interface,
        allocator,
    );

    // 3. Set network manager on runtime context for async fetch()
    if (options.network_manager) |nm| {
        runtime_ctx.setNetworkManager(nm);
    }

    // 4. Populate Zig-side template registry AND reinstall constructors with fresh callbacks
    interface_bindings.registerAllTemplatesOnly(isolate, v8_ctx, .eager);

    // 5. Reinstall accessor callbacks after snapshot restore.
    // NOTE: The optimization from whatwg-8oip3 that skipped this was WRONG.
    // NEW ARCHITECTURE (whatwg-izjpz): On-demand template creation
    // With minimal snapshot (only core interfaces), non-core interface templates are
    // created fresh on-demand with all accessors correctly installed from the start.
    // No reinstallation needed - eliminates the prototype identity bug.
    log.debug("[HYDRATE-WINDOW] Using on-demand template architecture (no accessor reinstall needed)\n", .{});

    // 6. Register namespaces (console, WebAssembly, etc.) - NOT in snapshot
    interface_bindings.registerNamespacesGeneric(namespaces_module, isolate, v8_ctx);

    // 7. Get the global object
    const global = v8.v8_Context_Global(v8_ctx) orelse {
        return error.NoGlobal;
    };

    // 8. Set up Window prototype chain: global → Window.prototype
    const window_key = v8.v8_String_NewFromUtf8(isolate, "Window", 6);
    if (window_key) |wk| {
        if (v8.v8_Object_Get(global, v8_ctx, @ptrCast(wk))) |window_ctor| {
            const proto_key = v8.v8_String_NewFromUtf8(isolate, "prototype", 9);
            if (proto_key) |pk| {
                if (v8.v8_Object_Get(@ptrCast(window_ctor), v8_ctx, @ptrCast(pk))) |window_proto| {
                    _ = v8.v8_Object_SetPrototypeV2(global, v8_ctx, window_proto);
                }
            }
        }
    }

    // 9. Create Window instance
    const Window = interfaces.Window;
    const window_instance = try Window.init(allocator, runtime_ctx);
    errdefer Window.deinit(window_instance);

    // 10. Bind Window instance to global object's internal fields
    // Field 0: instance pointer, Field 1: type info pointer
    // Use dom_type_info which has the actual type info definitions
    const dom_type_info_3 = @import("dom_type_info.zig");
    v8.v8_Object_SetAlignedPointerInInternalField(global, 0, @ptrCast(window_instance));
    if (dom_type_info_3.getTypeInfoByName("Window")) |type_info| {
        v8.v8_Object_SetAlignedPointerInInternalField(global, 1, @ptrCast(@constCast(type_info)));
    }

    // 11. Bind V8 global to Window instance for cross-realm access
    impls.Window.setBoundV8Global(window_instance, @ptrCast(global));

    // 12. Register Window in wrapper cache
    if (runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
        const cache: *WrapperCache = @ptrCast(@alignCast(cache_storage));
        try cache.set(window_instance, global, isolate);
    }

    // 13. Register Window with context manager (for getWindowForContext)
    try setWindowForContext(v8_ctx, window_instance);

    // 14. Register Window properties as own properties on global
    interface_bindings.Window.registerPropertiesAsOwnOnObject(isolate, v8_ctx, global);

    // 15. Register methods as own properties (Window + EventTarget methods)
    interface_bindings.Window.registerMethodsAsOwnOnObject(isolate, v8_ctx, global);
    interface_bindings.EventTarget.registerMethodsAsOwnOnObject(isolate, v8_ctx, global);

    // 16. Set self/window/frames as data properties equal to global
    // This is critical for testharness.js compatibility: (function(global_scope){...})(self)
    // requires that self === globalThis so that properties set on global_scope become
    // accessible as global variables. The accessor approach returns a new handle each time
    // which breaks object identity. Setting as data properties ensures self === globalThis.
    if (v8.v8_String_NewFromUtf8(isolate, "self", 4)) |self_prop_key| {
        _ = v8.v8_Object_Set(global, v8_ctx, @ptrCast(self_prop_key), @ptrCast(global));
    }
    if (v8.v8_String_NewFromUtf8(isolate, "window", 6)) |window_prop_key| {
        _ = v8.v8_Object_Set(global, v8_ctx, @ptrCast(window_prop_key), @ptrCast(global));
    }
    if (v8.v8_String_NewFromUtf8(isolate, "frames", 6)) |frames_prop_key| {
        _ = v8.v8_Object_Set(global, v8_ctx, @ptrCast(frames_prop_key), @ptrCast(global));
    }

    return WindowHydrationResult{
        .runtime_ctx = runtime_ctx,
        .window_instance = window_instance,
        .success = true,
    };
}

/// Hydrate a V8 context as a Worker context (from snapshot)
///
/// This function performs all post-snapshot hydration steps for Worker contexts:
/// 1. Populates Zig-side template registry (wrapInstanceAsV8Object support)
/// 2. Reinstalls accessor callbacks on prototypes (stale after snapshot load)
/// 3. Sets up basic worker globals (self, globalThis)
/// 4. Registers context with context manager
///
/// ## Worker-specific behavior
///
/// Workers do NOT get:
/// - document, location, navigator (DOM-specific)
/// - Window instance (workers use DedicatedWorkerGlobalScope)
///
/// Workers DO get:
/// - self (reference to global)
/// - postMessage (registered separately by worker setup)
/// - console (registered separately)
///
/// ## Usage
///
/// ```zig
/// const result = try context_manager.hydrateWorkerContext(.{
///     .isolate = isolate,
///     .context = v8_ctx,
///     .allocator = allocator,
/// });
/// ```
pub fn hydrateWorkerContext(options: HydrationOptions) !WorkerHydrationResult {
    const interface_bindings = @import("interface_bindings.zig");

    const isolate = options.isolate;
    const v8_ctx = options.context;
    const allocator = options.allocator;

    log.debug("[HYDRATE-WORKER] hydrateWorkerContext called, isolate={*}, context={*}\n", .{ isolate, v8_ctx });

    // 1. Initialize context manager (if not already initialized)
    init(allocator) catch |err| {
        if (err != error.AlreadyInitialized) {
            return err;
        }
    };

    // 2. Register context with context manager
    const runtime_ctx = try getOrCreate(v8_ctx, allocator);

    // 3. Populate Zig-side template registry AND reinstall constructors with fresh callbacks
    log.debug("[HYDRATE-WORKER] Calling registerAllTemplatesOnly...\\n", .{});
    interface_bindings.registerAllTemplatesOnly(isolate, v8_ctx, .lazy_follows);

    // NOTE: Accessor callback reinstallation is NO LONGER NEEDED after whatwg-41la6.
    // The Chromium pattern fix (calling GetFunction before NewInstance) ensures
    // prototype chains are materialized correctly during snapshot creation.

    log.debug("[HYDRATE-WORKER] hydrateWorkerContext complete\n", .{});

    // 6. Set up basic worker globals
    const global_obj = v8.v8_Context_Global(v8_ctx) orelse {
        return error.NoGlobal;
    };

    // 'self' = globalThis (reference to global object)
    const self_key = v8.v8_String_NewFromUtf8(isolate, "self", 4) orelse {
        return error.StringCreationFailed;
    };
    _ = v8.v8_Object_Set(global_obj, v8_ctx, @ptrCast(self_key), @ptrCast(global_obj));

    // 'globalThis' = global object
    const global_this_key = v8.v8_String_NewFromUtf8(isolate, "globalThis", 10) orelse {
        return error.StringCreationFailed;
    };
    _ = v8.v8_Object_Set(global_obj, v8_ctx, @ptrCast(global_this_key), @ptrCast(global_obj));

    return WorkerHydrationResult{
        .runtime_ctx = runtime_ctx,
        .success = true,
    };
}

/// Check if a context has Window-specific globals
///
/// Returns true if the context has 'document' as a property (Window context),
/// false if it has 'postMessage' but no 'document' (Worker context).
pub fn isWindowContext(isolate: *v8.Isolate, context: *v8.Context) bool {
    const global = v8.v8_Context_Global(context) orelse return false;

    // Check for 'document' property - Window contexts have this
    const doc_key = v8.v8_String_NewFromUtf8(isolate, "document", 8) orelse return false;
    const has_doc = v8.v8_Object_Has(global, context, @ptrCast(doc_key));

    return has_doc;
}

/// Check if a context is a Worker context
pub fn isWorkerContext(isolate: *v8.Isolate, context: *v8.Context) bool {
    const global = v8.v8_Context_Global(context) orelse return false;

    // Workers have 'self' but NOT 'document'
    const self_key = v8.v8_String_NewFromUtf8(isolate, "self", 4) orelse return false;
    const has_self = v8.v8_Object_Has(global, context, @ptrCast(self_key));

    const doc_key = v8.v8_String_NewFromUtf8(isolate, "document", 8) orelse return false;
    const has_doc = v8.v8_Object_Has(global, context, @ptrCast(doc_key));

    return has_self and !has_doc;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "ContextManager - init and deinit" {
    try init(testing.allocator);
    defer deinit();

    // Should be initialized
    try testing.expect(manager_state != null);
}

test "ContextManager - double init fails" {
    try init(testing.allocator);
    defer deinit();

    // Second init should fail
    try testing.expectError(error.AlreadyInitialized, init(testing.allocator));
}

test "ContextManager - getOrCreate creates new context" {
    try init(testing.allocator);
    defer deinit();

    // Create fake V8 context pointer (just for testing)
    var dummy_v8_ctx: u64 = 0x1000;
    const v8_ctx: *v8.Context = @ptrCast(&dummy_v8_ctx);

    // Get or create should create new context
    const ctx = try getOrCreate(v8_ctx, testing.allocator);
    try testing.expect(ctx.getAllocator().ptr == testing.allocator.ptr);
    try testing.expect(!ctx.hasEngine() or ctx.getEngineContext() != null);
}

test "ContextManager - getOrCreate returns same context" {
    try init(testing.allocator);
    defer deinit();

    var dummy_v8_ctx: u64 = 0x1000;
    const v8_ctx: *v8.Context = @ptrCast(&dummy_v8_ctx);

    const ctx1 = try getOrCreate(v8_ctx, testing.allocator);
    const ctx2 = try getOrCreate(v8_ctx, testing.allocator);

    // Should return same context
    try testing.expect(ctx1 == ctx2);
}

test "ContextManager - get returns null for non-existent context" {
    try init(testing.allocator);
    defer deinit();

    var dummy_v8_ctx: u64 = 0x1000;
    const v8_ctx: *v8.Context = @ptrCast(&dummy_v8_ctx);

    // Should return null
    try testing.expect(get(v8_ctx) == null);
}

test "ContextManager - get returns existing context" {
    try init(testing.allocator);
    defer deinit();

    var dummy_v8_ctx: u64 = 0x1000;
    const v8_ctx: *v8.Context = @ptrCast(&dummy_v8_ctx);

    _ = try getOrCreate(v8_ctx, testing.allocator);

    const ctx = get(v8_ctx);
    try testing.expect(ctx != null);
}

test "ContextManager - register does not own context" {
    try init(testing.allocator);
    defer deinit();

    var dummy_v8_ctx: u64 = 0x1000;
    const v8_ctx: *v8.Context = @ptrCast(&dummy_v8_ctx);

    // Create external context
    var external_ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer external_ctx.deinit(); // We own this

    // Register it
    try register(v8_ctx, &external_ctx);

    // Should be retrievable
    const ctx = get(v8_ctx);
    try testing.expect(ctx != null);

    // deinit() should not crash (shouldn't try to deinit external context)
}

test "ContextManager - removeContext cleans up owned context" {
    try init(testing.allocator);
    defer deinit();

    var dummy_v8_ctx: u64 = 0x1000;
    const v8_ctx: *v8.Context = @ptrCast(&dummy_v8_ctx);

    _ = try getOrCreate(v8_ctx, testing.allocator);

    // Remove should clean up
    removeContext(v8_ctx);

    // Should no longer exist
    try testing.expect(get(v8_ctx) == null);
}

test "ContextManager - multiple contexts" {
    try init(testing.allocator);
    defer deinit();

    var dummy1: u64 = 0x1000;
    var dummy2: u64 = 0x2000;
    const ctx1_v8: *v8.Context = @ptrCast(&dummy1);
    const ctx2_v8: *v8.Context = @ptrCast(&dummy2);

    const ctx1 = try getOrCreate(ctx1_v8, testing.allocator);
    const ctx2 = try getOrCreate(ctx2_v8, testing.allocator);

    // Should be different contexts
    try testing.expect(ctx1 != ctx2);
}

test "ContextManager - getEntry returns entry with parent/children" {
    try init(testing.allocator);
    defer deinit();

    var dummy_v8_ctx: u64 = 0x1000;
    const v8_ctx: *v8.Context = @ptrCast(&dummy_v8_ctx);

    _ = try getOrCreate(v8_ctx, testing.allocator);

    const entry = getEntry(v8_ctx);
    try testing.expect(entry != null);

    // Top-level context should have no parent
    try testing.expect(entry.?.parent_entry == null);

    // Top-level context should have empty children list
    try testing.expectEqual(@as(usize, 0), entry.?.children.items.len);

    // Top-level context created via getOrCreate should have no realm initially
    try testing.expect(entry.?.realm == null);
}

test "ContextManager - getRealmForContext returns null for context without realm" {
    try init(testing.allocator);
    defer deinit();

    var dummy_v8_ctx: u64 = 0x1000;
    const v8_ctx: *v8.Context = @ptrCast(&dummy_v8_ctx);

    _ = try getOrCreate(v8_ctx, testing.allocator);

    // Contexts created via getOrCreate don't have realms initially
    const realm = getRealmForContext(v8_ctx);
    try testing.expect(realm == null);
}

test "ContextManager - setRealmForContext associates realm with context" {
    try init(testing.allocator);
    defer deinit();

    var dummy_v8_ctx: u64 = 0x1000;
    const v8_ctx: *v8.Context = @ptrCast(&dummy_v8_ctx);

    _ = try getOrCreate(v8_ctx, testing.allocator);

    // Create a realm
    const realm = try runtime.Realm.init(testing.allocator, .{
        .context_type = .window,
    });
    // Note: realm will be cleaned up by context manager

    // Associate realm with context
    try setRealmForContext(v8_ctx, realm);

    // Should now be retrievable
    const retrieved_realm = getRealmForContext(v8_ctx);
    try testing.expect(retrieved_realm != null);
    try testing.expect(retrieved_realm == realm);
    try testing.expect(retrieved_realm.?.isWindow());
}
