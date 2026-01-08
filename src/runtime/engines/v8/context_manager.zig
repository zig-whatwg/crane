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
const v8 = @import("ffi.zig");
const runtime = @import("runtime");
const V8EventLoop = @import("event_loop.zig").V8EventLoop;
const v8_engine = @import("engine.zig");
const intl_binding = @import("intl_binding.zig");
const iface_bindings_mod = @import("interface_bindings.zig");
const helpers = @import("webidl").helpers;

/// Context mapping entry
pub const ContextEntry = struct {
    /// V8 context pointer (key)
    v8_ctx: *v8.Context,

    /// Runtime context data (owned)
    runtime_ctx: runtime.ContextData,

    /// Whether this entry owns the runtime context
    /// (and should deinit it when removed)
    owns_context: bool,

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

/// Set the callback for registering globals on child contexts
/// This should be called by the browser layer during initialization
pub fn setChildContextGlobalsCallback(callback: ChildContextGlobalsCallback) void {
    child_context_globals_callback = callback;
}

/// Clear the child context globals callback
pub fn clearChildContextGlobalsCallback() void {
    child_context_globals_callback = null;
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
        runtime.ObservableArrayExotic.cleanupAll();

        // Deinit all owned runtime contexts
        // Note: The order doesn't matter for cleanup because we skip onObjectFreed
        // during teardown (is_tearing_down flag prevents nested calls).
        var it = state.contexts.valueIterator();
        while (it.next()) |entry_ptr| {
            const entry = entry_ptr.*; // Dereference the pointer to get *ContextEntry
            if (entry.owns_context) {
                var ctx_data = entry.runtime_ctx;

                // Phase: DOM Tree cleanup
                // Clean up Window instance and its Document FIRST
                // This cleans up the DOM tree, and each Node.deinit removes itself
                // from the wrapper cache to prevent double-free.
                coordinator.cleanupPhase(.dom_tree);
                if (entry.window_instance) |window| {
                    const interfaces = @import("interfaces");
                    const WindowImpl = @import("impls").Window;

                    // Clean up Document instance first (owns the entire DOM tree)
                    if (WindowImpl.getInternal(window)) |internal| {
                        if (internal.document) |doc| {
                            interfaces.Document.deinit(doc);
                            internal.document = null;
                        }
                    }

                    interfaces.Window.deinit(window);
                }

                // Phase: Wrapper Cache cleanup
                // Clean up V8 wrapper cache WITH callbacks
                // Now safe to call deinit() because:
                // 1. DOM nodes already removed themselves from cache via Node.deinit
                // 2. Remaining entries are non-DOM objects (AbortController, etc.)
                // 3. These need their deinit called to free InternalState
                coordinator.cleanupPhase(.wrapper_cache);
                if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
                    const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
                    cache_ptr.deinit();
                    ctx_data.getAllocator().destroy(cache_ptr);
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
                    realm.deinit();
                }

                // Clean up children list (entries themselves are in the map)
                var children = entry.children;
                children.deinit(entry.allocator);

                // Phase: Context Data cleanup
                coordinator.cleanupPhase(.context_data);
                ctx_data.deinit();
            }
            // Free the heap-allocated entry itself
            state.allocator.destroy(entry);
        }

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
        .engine = &v8_engine.v8_engine_interface,
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
        .children = .{},
        .allocator = allocator,
    };

    // Store pointer in map - entry won't move even if HashMap rehashes
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
            .v8_context = @ptrCast(v8_ctx),
            .isolate = @ptrCast(isolate),
            .context_type = .window,
            .global_object = window_instance, // Set directly since we have the Window
        });
        // Populate intrinsics for cross-realm support
        _ = realm.populateIntrinsics();

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
        .engine = &v8_engine.v8_engine_interface, // V8 engine interface for Promises etc.
        .engine_ctx = @ptrCast(v8_ctx), // Store V8 context as engine context
        .timer = timer_interface,
        .event_loop = event_loop_interface,
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

    // Create realm for cross-realm support (only if we have an isolate)
    // Per WebIDL, every context has an associated realm with intrinsics
    // Note: global_object is set to null here and will be populated later by
    // bindWindowToContext() when the Window instance is created
    var realm: ?*runtime.Realm = null;
    if (isolate) |iso| {
        realm = try runtime.Realm.init(allocator, .{
            .v8_context = @ptrCast(v8_ctx),
            .isolate = @ptrCast(iso),
            .context_type = .window, // Main context is a window
            .global_object = null, // Set by bindWindowToContext() after Window creation
        });
        errdefer if (realm) |r| r.deinit();

        // Populate realm intrinsics for cross-realm support
        _ = realm.?.populateIntrinsics();

        // Set realm on runtime context so impl code can access via instance.ctx.realm
        ctx_data.setRealm(realm.?);
    }

    // Register dynamic import handler for this isolate
    // This enables import() expressions in JavaScript per HTML spec HostImportModuleDynamically
    if (isolate) |iso| {
        v8_engine.setDynamicImportHandler(iso, .{
            .callback = handleDynamicImport,
            .context = @ptrCast(v8_ctx),
        });
    }

    // Heap-allocate the entry so it doesn't move when HashMap rehashes
    const entry = try state.allocator.create(ContextEntry);
    errdefer state.allocator.destroy(entry);

    entry.* = ContextEntry{
        .v8_ctx = v8_ctx,
        .runtime_ctx = ctx_data,
        .owns_context = true,
        .event_loop = event_loop_ptr,
        .realm = realm,
        .parent_entry = null,
        .children = .{},
        .allocator = allocator,
    };

    // Store pointer in map - entry won't move even if HashMap rehashes
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
    std.debug.print("[HYDRATE-SNAPSHOT] hydrateContextFromSnapshot called, context={*}, scope={s}\n", .{ v8_ctx, @tagName(scope) });

    // Use inline for to convert runtime scope to comptime for installForScope
    inline for (std.meta.fields(helpers.GlobalScope)) |field| {
        if (scope == @field(helpers.GlobalScope, field.name)) {
            // V8 snapshots don't preserve lazy data properties on the global proxy.
            // We must re-install them after context restoration (matches Chromium's pattern).
            const global_constructor_handler = @import("global_constructor_handler.zig");
            global_constructor_handler.installLazyConstructorsOnGlobal(v8_ctx);

            // CRITICAL FIX (whatwg-gy5zk): V8 snapshots do NOT preserve native accessor callbacks.
            // Even with external references registered, the accessor callbacks in snapshot prototypes
            // are disconnected from the actual Zig functions. This affects ALL contexts, not just workers.
            //
            // The previous "on-demand creation" assumption was WRONG because:
            // 1. wrapInstanceAsV8Object() uses existing prototypes from global.Constructor.prototype
            // 2. Those prototypes come from the snapshot with broken accessor callbacks
            // 3. Without reinstallation, accessing properties like MessageEvent.data returns undefined
            //
            // We MUST reinstall accessor callbacks on ALL interface prototypes after snapshot restore.
            const interface_bindings = @import("interface_bindings.zig");
            std.debug.print("[HYDRATE-SNAPSHOT] Reinstalling accessor callbacks on ALL interface prototypes...\n", .{});
            interface_bindings.reinstallAllAccessorCallbacks(isolate, v8_ctx);

            std.debug.print("[HYDRATE-SNAPSHOT] Context hydrated with lazy constructors and accessor callbacks, scope={s}\n", .{@tagName(scope)});
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
        .children = .{},
        .allocator = state.allocator,
    };

    // Link to parent if provided
    if (parent) |p| {
        try p.children.append(state.allocator, entry);
    }

    // Store in contexts HashMap
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
        .children = .{},
        .allocator = state.allocator,
    };

    // Store pointer in map - entry won't move even if HashMap rehashes
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
    const state = &(manager_state orelse return);

    // Use the raw V8 internal address as the key (must match getOrCreate*)
    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return;
    const key = @intFromPtr(raw_addr);

    if (state.contexts.fetchRemove(key)) |kv| {
        const entry = kv.value; // This is now *ContextEntry
        defer state.allocator.destroy(entry); // Free the heap-allocated entry
        if (entry.owns_context) {
            var ctx_data = entry.runtime_ctx;
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

            // Clean up Window and Document (DOM tree) before wrapper cache
            // This is critical: DOM nodes remove themselves from the wrapper cache
            // during deinit, so we must clean them up first
            coordinator.cleanupPhase(.dom_tree);
            if (entry.window_instance) |window| {
                const interfaces = @import("interfaces");
                const WindowImpl = @import("impls").Window;

                // Clean up Document instance first (owns the entire DOM tree)
                if (WindowImpl.getInternal(window)) |internal| {
                    if (internal.document) |doc| {
                        interfaces.Document.deinit(doc);
                        internal.document = null;
                    }
                }

                interfaces.Window.deinit(window);
            }

            // Clean up V8 wrapper cache
            // Now safe because DOM nodes already removed themselves
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
                realm.deinit();
            }

            // Clean up children list
            entry.children.deinit(entry.allocator);

            ctx_data.deinit();
        }
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
// Dynamic Import Handler
// ============================================================================

/// Handle dynamic import() expressions from JavaScript
///
/// This callback is invoked by V8 when JavaScript uses import().
/// It implements the HostImportModuleDynamically abstract operation from HTML spec.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#hostimportmoduledynamically
///
/// Note: Module fetching is handled via std.net for now. A full implementation
/// would integrate with the Fetch API but that requires circular dependency resolution.
fn handleDynamicImport(
    ctx: ?*anyopaque,
    referrer: []const u8,
    specifier: []const u8,
    resolver: v8_engine.DynamicImportResolver,
) void {
    const v8_ctx: *v8.Context = @ptrCast(@alignCast(ctx orelse {
        resolver.reject("No context available for dynamic import");
        return;
    }));

    // Get isolate from context
    const isolate = v8.v8_Isolate_GetCurrent() orelse {
        resolver.reject("No V8 isolate available");
        return;
    };

    // Try to get runtime context for allocator
    const state = manager_state orelse {
        resolver.reject("Context manager not initialized");
        return;
    };

    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse {
        resolver.reject("Invalid V8 context");
        return;
    };
    const key = @intFromPtr(raw_addr);

    const entry = state.contexts.get(key) orelse {
        resolver.reject("No runtime context for this V8 context");
        return;
    };

    const allocator = entry.runtime_ctx.allocator;

    // Resolve the specifier to a URL
    // For now, we only handle URL-like specifiers (absolute or relative)
    const resolved_url = resolveModuleSpecifier(allocator, specifier, referrer) catch {
        resolver.reject("Failed to resolve module specifier");
        return;
    };
    defer if (resolved_url.ptr != specifier.ptr) allocator.free(resolved_url);

    // Check for supported URL schemes
    // For now, we only support file:// URLs or relative paths
    if (!std.mem.startsWith(u8, resolved_url, "file://") and
        std.mem.indexOf(u8, resolved_url, "://") != null)
    {
        // HTTP/HTTPS URLs require fetch integration which isn't available here
        // The script_execution.zig handler has access to fetch and should be used
        // for full HTTP module loading
        resolver.reject("Dynamic import of HTTP URLs not supported in this context. Use script_execution for HTTP module loading.");
        return;
    }

    // For file:// URLs, read the file directly
    var file_path: []const u8 = resolved_url;
    if (std.mem.startsWith(u8, resolved_url, "file://")) {
        file_path = resolved_url[7..]; // Strip "file://"
    }

    // Read the file
    const file = std.fs.cwd().openFile(file_path, .{}) catch {
        resolver.reject("Failed to open module file");
        return;
    };
    defer file.close();

    const source = file.readToEndAlloc(allocator, 10 * 1024 * 1024) catch { // 10MB max
        resolver.reject("Failed to read module file");
        return;
    };
    defer allocator.free(source);

    // Compile the module
    const source_str = v8.v8_String_NewFromUtf8(
        isolate,
        source.ptr,
        @intCast(source.len),
    ) orelse {
        resolver.reject("Failed to create source string");
        return;
    };

    const url_str = v8.v8_String_NewFromUtf8(
        isolate,
        resolved_url.ptr,
        @intCast(resolved_url.len),
    ) orelse {
        resolver.reject("Failed to create URL string");
        return;
    };

    const module = v8.v8_Module_Compile(v8_ctx, source_str, url_str) orelse {
        resolver.reject("Failed to compile module");
        return;
    };

    // Instantiate the module
    if (!v8.v8_Module_Instantiate(v8_ctx, module)) {
        v8.v8_Module_Dispose(module);
        resolver.reject("Failed to instantiate module");
        return;
    }

    // Evaluate the module
    const eval_result = v8.v8_Module_Evaluate(v8_ctx, module);
    if (eval_result == null) {
        v8.v8_Module_Dispose(module);
        resolver.reject("Failed to evaluate module");
        return;
    }

    // Get module namespace and resolve the promise
    const namespace = v8.v8_Module_GetModuleNamespace(module) orelse {
        v8.v8_Module_Dispose(module);
        resolver.reject("Failed to get module namespace");
        return;
    };

    resolver.resolve(namespace);
}

/// Resolve a module specifier to a URL
fn resolveModuleSpecifier(
    allocator: std.mem.Allocator,
    specifier: []const u8,
    referrer: []const u8,
) ![]const u8 {
    // Absolute URL
    if (std.mem.indexOf(u8, specifier, "://") != null) {
        return specifier;
    }

    // Root-relative URL
    if (specifier.len > 0 and specifier[0] == '/') {
        // Extract origin from referrer
        if (std.mem.indexOf(u8, referrer, "://")) |scheme_end| {
            const after_scheme = scheme_end + 3;
            const origin_end = if (std.mem.indexOfPos(u8, referrer, after_scheme, "/")) |slash|
                slash
            else
                referrer.len;

            const result = try allocator.alloc(u8, origin_end + specifier.len);
            @memcpy(result[0..origin_end], referrer[0..origin_end]);
            @memcpy(result[origin_end..], specifier);
            return result;
        }
        return specifier;
    }

    // Relative URL (./xxx or ../xxx)
    if (specifier.len >= 2 and specifier[0] == '.') {
        // Find the base path (everything up to and including the last /)
        var base_path_end: usize = 0;
        if (std.mem.lastIndexOf(u8, referrer, "/")) |last_slash| {
            base_path_end = last_slash + 1;
        }

        if (base_path_end > 0) {
            const result = try allocator.alloc(u8, base_path_end + specifier.len);
            @memcpy(result[0..base_path_end], referrer[0..base_path_end]);
            @memcpy(result[base_path_end..], specifier);
            return result;
        }
    }

    // Bare specifier - would need import map resolution
    // For now, return as-is (will likely fail)
    return specifier;
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

    // Use comptime-generated registry which has ALL interfaces
    const wrapper_type_info_registry = @import("wrapper_type_info_registry.zig");
    if (wrapper_type_info_registry.getWrapperTypeInfoByName("Window")) |type_info| {
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
    _ = v8.v8_Object_Set(global, v8_ctx, @ptrCast(window_key), @ptrCast(global));

    const self_key = v8.v8_String_NewFromUtf8(isolate, "self", 4) orelse return error.StringCreationFailed;
    _ = v8.v8_Object_Set(global, v8_ctx, @ptrCast(self_key), @ptrCast(global));

    const global_this_key = v8.v8_String_NewFromUtf8(isolate, "globalThis", 10) orelse return error.StringCreationFailed;
    _ = v8.v8_Object_Set(global, v8_ctx, @ptrCast(global_this_key), @ptrCast(global));

    return window_instance;
}

/// Options for creating a child context
pub const ChildContextOptions = struct {
    /// Parent V8 context (required)
    parent_context: *v8.Context,

    /// V8 isolate (required)
    isolate: *v8.Isolate,

    /// Context type for the child realm (defaults to window for iframes)
    context_type: runtime.ContextType = .window,

    /// Whether to inherit the event loop from parent
    inherit_event_loop: bool = true,

    /// Existing browsing context to use (optional).
    /// If provided, the Window will use this browsing context instead of creating a new one.
    /// This is used for iframes where the browsing context is created when the iframe
    /// is inserted into the DOM (via IFrameIntegration.onInsertedIntoDocument).
    /// The Window will be set as the active window on this browsing context.
    existing_browsing_context: ?*anyopaque = null,
};

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
    const NodeImpl = impls.Node;
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
    NodeImpl.setOwnerDocument(html_element, document) catch {
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
    NodeImpl.setOwnerDocument(head_element, document) catch {
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
    NodeImpl.setOwnerDocument(body_element, document) catch {
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

/// Create a V8 context and Window for an existing BrowsingContext
///
/// This is used by the indexed property getter to lazily create the V8 context
/// when frames[index] is accessed but the child browsing context doesn't have
/// an active Window yet.
///
/// Unlike createChildContext, this function does NOT create a new BrowsingContext.
/// It uses the existing one and sets the active_window on it.
///
/// Returns the created Window instance, or null on error.
///
/// Note: Uses *anyopaque for the BrowsingContext type to avoid circular module
/// dependencies. The caller is responsible for ensuring the pointer is valid.
fn createWindowForExistingBrowsingContext(
    parent_context: *v8.Context,
    isolate: *v8.Isolate,
    child_bc_opaque: *anyopaque,
    allocator: std.mem.Allocator,
) ?*runtime.Instance {
    const state = &(manager_state orelse return null);
    const interfaces = @import("interfaces");
    const interface_bindings = @import("interface_bindings.zig");
    const WindowImpl = @import("impls").Window;

    // Get parent entry for inheriting event loop
    const parent_raw_addr = v8.v8_Context_GetRawAddress(parent_context) orelse return null;
    const parent_key = @intFromPtr(parent_raw_addr);
    const parent_entry = state.contexts.get(parent_key) orelse return null;

    // 1. Create new V8 context from snapshot (interfaces already registered)
    const child_context = v8.v8_Context_NewFromSnapshot(isolate) orelse return null;

    const child_raw_addr = v8.v8_Context_GetRawAddress(child_context) orelse return null;
    const child_key = @intFromPtr(child_raw_addr);

    // 2b. Set security token to match parent context (same-origin for iframes)
    if (v8.v8_Context_GetSecurityToken(parent_context)) |parent_token| {
        v8.v8_Context_SetSecurityToken(child_context, parent_token);
    }

    // 3. Enter the new context for initialization
    v8.v8_Context_Enter(child_context);
    defer v8.v8_Context_Exit(child_context);

    // 4. Interfaces already registered via snapshot - set up prototype chain
    // This inserts WindowProperties into Window.prototype's chain:
    //   Window.prototype → WindowProperties → EventTarget.prototype

    // 4b. Set global's prototype to Window.prototype to complete the chain:
    //   global → Window.prototype → WindowProperties → EventTarget.prototype
    // Per WebIDL §3.8 step 9, platform objects have their [[Prototype]] set to
    // the interface prototype object (Window.prototype for the global).
    const global = v8.v8_Context_Global(child_context) orelse return null;
    const window_key = v8.v8_String_NewFromUtf8(isolate, "Window", 6);
    if (window_key) |wk| {
        if (v8.v8_Object_Get(global, child_context, @ptrCast(wk))) |window_ctor| {
            const proto_key = v8.v8_String_NewFromUtf8(isolate, "prototype", 9);
            if (proto_key) |pk| {
                if (v8.v8_Object_Get(@ptrCast(window_ctor), child_context, @ptrCast(pk))) |window_proto| {
                    _ = v8.v8_Object_SetPrototypeV2(global, child_context, window_proto);
                }
            }
        }
    }

    // 4c. Register Window properties as own properties on the global
    interface_bindings.Window.registerPropertiesAsOwnOnObject(isolate, child_context, global);

    // 4d. Register browser-level globals (setTimeout, setInterval, etc.)
    // These are essential for web platform functionality and are set by the browser layer.
    if (child_context_globals_callback) |callback| {
        callback(isolate, child_context, global);
    }

    // 5. Create realm
    const realm = runtime.Realm.init(allocator, .{
        .v8_context = @ptrCast(child_context),
        .isolate = @ptrCast(isolate),
        .context_type = .window,
        .global_object = null, // Will be set to Window instance below
    }) catch return null;
    _ = realm.populateIntrinsics();

    // 6. Create runtime context data
    var timer_interface: ?runtime.TimerInterface = null;
    var event_loop_interface: ?@import("event_loop").EventLoop = null;
    if (parent_entry.event_loop) |parent_ev_loop| {
        timer_interface = parent_ev_loop.timerInterface();
        event_loop_interface = parent_ev_loop.eventLoop();
    }

    var ctx_data = runtime.ContextData.init(allocator, .{
        .colored = false,
        .show_timestamp = false,
        .show_labels = false,
        .engine = &v8_engine.v8_engine_interface,
        .engine_ctx = @ptrCast(child_context),
        .timer = timer_interface,
        .event_loop = event_loop_interface,
    }) catch return null;

    // 7. Initialize V8 wrapper cache
    const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
    const cache_ptr = allocator.create(WrapperCache) catch return null;
    cache_ptr.* = WrapperCache.init(allocator, child_context) catch {
        allocator.destroy(cache_ptr);
        return null;
    };
    ctx_data.setV8WrapperCacheStorage(@ptrCast(cache_ptr));

    // 8. Create Window instance bound to the V8 global
    const runtime_ctx: runtime.Context = &ctx_data;
    const window_instance = interfaces.Window.init(allocator, runtime_ctx) catch return null;

    // Set the realm's global_object to the Window instance for cross-realm support.
    // This allows DOMParser and other APIs to correctly identify their realm's global.
    realm.setGlobalObject(@ptrCast(window_instance));

    // 8b. Replace the Window's auto-created browsing context with the existing one
    // This is necessary because:
    // - Window.init() creates its own top-level browsing context
    // - We need to use the iframe's existing one (already in parent's children list)
    WindowImpl.replaceBrowsingContext(window_instance, child_bc_opaque);

    // 8c. Create and set a Document for this iframe window
    // Per HTML spec, every Window must have an associated Document.
    // For cross-realm tests, properties like `iframe.contentWindow.document` must work.
    const document_instance = interfaces.Document.init(allocator, runtime_ctx) catch return null;
    WindowImpl.setDocument(window_instance, document_instance);

    // 9. Bind Window to global (internal fields + wrapper cache)
    // Use comptime-generated registry which has ALL interfaces
    const wrapper_type_info_registry_2 = @import("wrapper_type_info_registry.zig");
    v8.v8_Object_SetAlignedPointerInInternalField(global, 0, @ptrCast(window_instance));
    if (wrapper_type_info_registry_2.getWrapperTypeInfoByName("Window")) |type_info| {
        v8.v8_Object_SetAlignedPointerInInternalField(global, 1, @ptrCast(@constCast(type_info)));
    }
    WindowImpl.setBoundV8Global(window_instance, @ptrCast(global));
    cache_ptr.set(window_instance, global, isolate) catch {};

    // 10. Insert WindowProperties into prototype chain NOW that Window instance exists
    // This must happen AFTER the Window instance is bound to the global's internal field
    // so that named property lookups can find the correct Window (especially for cross-realm access).
    const window_properties = @import("window_properties.zig");
    _ = window_properties.insertIntoPrototypeChain(isolate, child_context, window_instance);

    // 11. Heap-allocate entry so it doesn't move when HashMap rehashes
    const child_entry = state.allocator.create(ContextEntry) catch return null;

    child_entry.* = ContextEntry{
        .v8_ctx = child_context,
        .runtime_ctx = ctx_data,
        .owns_context = true,
        .event_loop = null,
        .realm = realm,
        .parent_entry = parent_entry,
        .children = .{},
        .allocator = allocator,
        .window_instance = window_instance,
    };

    // Store pointer in map - entry won't move even if HashMap rehashes
    // This MUST happen before initializeIframeDocumentStructure because
    // element creation uses the wrapper cache which needs the context registered.
    state.contexts.put(child_key, child_entry) catch {
        state.allocator.destroy(child_entry);
        return null;
    };

    // 11b. Fix up document.ctx to point to stable location
    document_instance.ctx = &child_entry.runtime_ctx;

    // 11c. Initialize document with standard HTML structure (html > head + body)
    // Per HTML spec, a new browsing context's document should have this structure
    // to ensure document.body, document.head, and document.documentElement work.
    // NOTE: This must happen AFTER the context is registered in the map (step 11)
    // because element creation uses wrapper cache which needs context lookup.
    initializeIframeDocumentStructure(allocator, &child_entry.runtime_ctx, document_instance);

    // 12. Link to parent's children list
    parent_entry.children.append(allocator, child_entry) catch {};

    return window_instance;
}

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

            // Child browsing context exists but no Window - create it
            if (child_bc.getActiveWindow() == null) {
                // Get the allocator from the context entry
                const entry = getEntry(v8_context) orelse return .kNo;

                // Create a V8 context and Window for the existing BrowsingContext
                result = createWindowForExistingBrowsingContext(
                    v8_context,
                    isolate,
                    child_bc,
                    entry.allocator,
                );
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
    const WindowImpl = @import("impls").Window;

    const this_obj = info.getThis();
    const instance_ptr = v8.v8_Object_GetAlignedPointerFromInternalField(this_obj, 0);
    if (instance_ptr == null) return .kNo;

    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));

    // Check if this index is valid
    const length = WindowImpl.get_length(instance) catch return .kNo;
    if (index < length) {
        // Valid index - return property attributes (ReadOnly | DontEnum)
        // Per spec, indexed properties on Window are configurable but not writable
        const isolate = info.getIsolate();
        const attrs = v8.v8_Integer_New(isolate, 3); // 3 = ReadOnly | DontEnum
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
    const WindowImpl = @import("impls").Window;

    const isolate = info.getIsolate();
    const v8_context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    const this_obj = info.getThis();
    const instance_ptr = v8.v8_Object_GetAlignedPointerFromInternalField(this_obj, 0);
    if (instance_ptr == null) {
        // No instance - return empty array
        info.setReturnValue(@ptrCast(v8.v8_Array_New(isolate, 0)));
        return;
    }

    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));
    const length = WindowImpl.get_length(instance) catch {
        info.setReturnValue(@ptrCast(v8.v8_Array_New(isolate, 0)));
        return;
    };

    // Create array of indices as integers
    // V8's indexed property interceptor expects integer indices here.
    // V8 internally converts these to strings when needed for ownKeys.
    const arr = v8.v8_Array_New(isolate, @intCast(length));
    var i: u32 = 0;
    while (i < length) : (i += 1) {
        const idx_val = v8.v8_Integer_New(isolate, @intCast(i));
        _ = v8.v8_Array_Set(arr, v8_context, i, @ptrCast(idx_val));
    }
    info.setReturnValue(@ptrCast(arr));
}

/// Create a new V8 context for a child browsing context (iframe)
///
/// This creates a new V8 context with:
/// - Its own global object template with immutable prototype
/// - All interface bindings initialized
/// - A new realm associated with the context
/// - Parent-child relationship tracked
///
/// The child context is registered in the context manager and will be
/// cleaned up when destroyChildContext is called or when the manager
/// is deinitialized.
///
/// Thread safety: Thread-local, no synchronization needed
///
/// Arguments:
/// - options: Configuration for the child context
/// - allocator: Allocator for child context resources
///
/// Returns: Pointer to the created ContextEntry
pub fn createChildContext(
    options: ChildContextOptions,
    allocator: std.mem.Allocator,
) !*ContextEntry {
    const state = &(manager_state orelse return error.NotInitialized);

    // Get parent entry
    const parent_raw_addr = v8.v8_Context_GetRawAddress(options.parent_context) orelse return error.InvalidContext;
    const parent_key = @intFromPtr(parent_raw_addr);
    const parent_entry = state.contexts.get(parent_key) orelse return error.ParentNotFound;

    // 1. Create new V8 context from snapshot (interfaces already registered)
    const child_context = v8.v8_Context_NewFromSnapshot(
        options.isolate,
    ) orelse return error.ContextCreationFailed;

    // Get stable address for map key
    const child_raw_addr = v8.v8_Context_GetRawAddress(child_context) orelse return error.InvalidContext;
    const child_key = @intFromPtr(child_raw_addr);

    // 2b. Set security token to match parent context (same-origin for iframes)
    // This allows cross-context property access without "no access" errors.
    // In a real browser, this would only be done for same-origin iframes.
    // For now, we treat all iframes as same-origin for testing purposes.
    if (v8.v8_Context_GetSecurityToken(options.parent_context)) |parent_token| {
        v8.v8_Context_SetSecurityToken(child_context, parent_token);
    }

    // 3. Enter the new context for initialization
    v8.v8_Context_Enter(child_context);
    defer v8.v8_Context_Exit(child_context);

    // 4. Interfaces already registered via snapshot - set up prototype chain
    //   global → Window.prototype → WindowProperties → EventTarget.prototype
    // Per WebIDL §3.8 step 9, platform objects have their [[Prototype]] set to
    // the interface prototype object (Window.prototype for the global).
    const global = v8.v8_Context_Global(child_context) orelse return error.GlobalNotFound;
    const window_key = v8.v8_String_NewFromUtf8(options.isolate, "Window", 6);
    if (window_key) |wk| {
        if (v8.v8_Object_Get(global, child_context, @ptrCast(wk))) |window_ctor| {
            const proto_key = v8.v8_String_NewFromUtf8(options.isolate, "prototype", 9);
            if (proto_key) |pk| {
                if (v8.v8_Object_Get(@ptrCast(window_ctor), child_context, @ptrCast(pk))) |window_proto| {
                    _ = v8.v8_Object_SetPrototypeV2(global, child_context, window_proto);
                }
            }
        }
    }

    // 4c. Register Window properties as OWN properties on the global object
    // This is required for cross-realm WPT compliance:
    // `Object.getOwnPropertyDescriptor(iframe.contentWindow, "name")` must return
    // a descriptor with getter/setter, not undefined.
    // Per WebIDL §3.8: For [Global] interfaces, the global object should have
    // the interface's properties as own properties (not just inherited).
    const interface_bindings = @import("interface_bindings.zig");
    interface_bindings.Window.registerPropertiesAsOwnOnObject(
        options.isolate,
        child_context,
        global,
    );

    // 4d. Register Window methods as OWN properties on the global object
    // This is required for cross-realm WPT compliance:
    // `Object.create(iframe.contentWindow).focus()` must work because
    // methods should be accessible through the prototype chain.
    // Per WebIDL §3.8: For [Global] interfaces, the global object should have
    // the interface's operations as own properties (callable functions).
    interface_bindings.Window.registerMethodsAsOwnOnObject(
        options.isolate,
        child_context,
        global,
    );

    // 4d2. Set self/window/frames as DATA properties pointing to global
    // This is CRITICAL for testharness.js compatibility:
    // (function(global_scope){...})(self) requires self === globalThis
    // so that properties set on global_scope become true global bindings.
    if (v8.v8_String_NewFromUtf8(options.isolate, "self", 4)) |self_str| {
        _ = v8.v8_Object_Set(global, child_context, @ptrCast(self_str), @ptrCast(global));
    }
    if (v8.v8_String_NewFromUtf8(options.isolate, "window", 6)) |window_str| {
        _ = v8.v8_Object_Set(global, child_context, @ptrCast(window_str), @ptrCast(global));
    }
    if (v8.v8_String_NewFromUtf8(options.isolate, "frames", 6)) |frames_str| {
        _ = v8.v8_Object_Set(global, child_context, @ptrCast(frames_str), @ptrCast(global));
    }

    // 4e. Register browser-level globals (setTimeout, setInterval, etc.)
    // These are not WebIDL interfaces but are essential for web platform functionality.
    // The browser layer sets a callback via setChildContextGlobalsCallback() that
    // registers these globals. This separation ensures the runtime layer doesn't
    // depend on the browser layer.
    if (child_context_globals_callback) |callback| {
        callback(options.isolate, child_context, global);
    }

    // 5. Create realm for new context
    // Note: global_object is set to null initially and will be updated below
    // after the Window instance is created
    const realm = try runtime.Realm.init(allocator, .{
        .v8_context = @ptrCast(child_context),
        .isolate = @ptrCast(options.isolate),
        .context_type = options.context_type,
        .global_object = null, // Will be set to Window instance below
    });
    errdefer realm.deinit();

    // 5b. Populate realm intrinsics for cross-realm support
    // This caches the realm's built-in constructors (TypeError, Object, Array, etc.)
    // which are needed for proper cross-realm object/error creation.
    _ = realm.populateIntrinsics();

    // 6. Create runtime context data
    // Optionally inherit event loop from parent
    var timer_interface: ?runtime.TimerInterface = null;
    var event_loop_interface: ?@import("event_loop").EventLoop = null;

    if (options.inherit_event_loop) {
        if (parent_entry.event_loop) |parent_ev_loop| {
            timer_interface = parent_ev_loop.timerInterface();
            event_loop_interface = parent_ev_loop.eventLoop();
        }
    }

    var ctx_data = try runtime.ContextData.init(allocator, .{
        .colored = false,
        .show_timestamp = false,
        .show_labels = false,
        .engine = &v8_engine.v8_engine_interface,
        .engine_ctx = @ptrCast(child_context),
        .timer = timer_interface,
        .event_loop = event_loop_interface,
    });
    errdefer ctx_data.deinit();

    // 7. Initialize V8 wrapper cache for child context
    const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
    const cache_ptr = try allocator.create(WrapperCache);
    errdefer allocator.destroy(cache_ptr);

    cache_ptr.* = try WrapperCache.init(allocator, child_context);
    errdefer cache_ptr.deinit();

    ctx_data.setV8WrapperCacheStorage(@ptrCast(cache_ptr));

    // 7b. Set realm on runtime context for cross-realm support
    // This enables impl code to access the realm via instance.ctx.realm
    // Critical for DOMParser.parseFromString to get the correct documentURI
    ctx_data.setRealm(realm);

    // 8. Create Window instance bound to the V8 global
    // This is critical for cross-realm support: the Window instance IS the V8 global,
    // so `iframe.contentWindow.DOMRectReadOnly` works correctly.
    const runtime_ctx: runtime.Context = &ctx_data;
    const window_instance = try createWindowBoundToGlobal(
        allocator,
        runtime_ctx,
        child_context,
        options.isolate,
    );
    errdefer {
        // Clean up Window instance on error
        const interfaces = @import("interfaces");
        interfaces.Window.deinit(window_instance);
    }

    // 8a. Set the realm's global_object to the Window instance
    // This is required for DOMParser.parseFromString to get the correct documentURI
    realm.setGlobalObject(window_instance);

    // 8b. Handle browsing context for the Window
    const WindowImpl = @import("impls").Window;

    if (options.existing_browsing_context) |existing_bc| {
        // An existing browsing context was provided (from iframe's IFrameIntegration).
        // Replace the auto-created one with the existing one.
        // This is necessary because:
        // - IFrameIntegration.onInsertedIntoDocument() already created a child browsing context
        //   and added it to the parent's children list
        // - Window.init() creates its own top-level browsing context
        // - We need to use the iframe's existing one so frames[index] works correctly
        WindowImpl.replaceBrowsingContext(window_instance, existing_bc);
    } else {
        // No existing browsing context provided - link the auto-created one to parent.
        // This enables `window.frames[0]` to work by adding the child to parent's children list.
        // Without this, the child Window's browsing context is orphaned (created as top-level).
        if (parent_entry.window_instance) |parent_window| {
            // Get parent Window's browsing context
            if (WindowImpl.getInternal(parent_window)) |parent_internal| {
                // Get child Window's browsing context
                if (WindowImpl.getInternal(window_instance)) |child_internal| {
                    // Link child to parent
                    const parent_bc = parent_internal.browsing_context;
                    const child_bc = child_internal.browsing_context;

                    // Set parent reference and add to parent's children list
                    child_bc.parent = parent_bc;
                    parent_bc.children.append(parent_bc.allocator, child_bc) catch {
                        // Best effort - if this fails, frames[n] just won't work
                        // but contentWindow will still work via the context_manager path
                    };
                }
            }
        }
    }

    // 8c. Create and set a Document for this iframe window
    // Per HTML spec, every Window must have an associated Document.
    // For cross-realm tests, properties like `iframe.contentWindow.document` must work.
    const interfaces = @import("interfaces");
    const document_instance = try interfaces.Document.init(allocator, runtime_ctx);
    WindowImpl.setDocument(window_instance, document_instance);

    // 8d. Set the Document on the BrowsingContext so that contentDocument works.
    // HTMLIFrameElement.get_contentDocument() calls browsing_context.getActiveDocument(),
    // so we MUST set it here. Without this, contentDocument returns null.
    if (WindowImpl.getInternal(window_instance)) |win_internal| {
        win_internal.browsing_context.setActiveDocument(document_instance, window_instance);
    }

    // 9. Heap-allocate the entry so it doesn't move when HashMap rehashes
    const child_entry = try state.allocator.create(ContextEntry);
    errdefer state.allocator.destroy(child_entry);

    child_entry.* = ContextEntry{
        .v8_ctx = child_context,
        .runtime_ctx = ctx_data,
        .owns_context = true,
        .event_loop = null, // Child doesn't own event loop (inherits from parent or none)
        .realm = realm,
        .parent_entry = parent_entry, // Can set directly now - parent_entry is stable
        .children = .{},
        .allocator = allocator,
        .window_instance = window_instance,
    };

    // Store pointer in map - entry won't move even if HashMap rehashes
    // This MUST happen before initializeIframeDocumentStructure because
    // element creation uses the wrapper cache which needs the context registered.
    try state.contexts.put(child_key, child_entry);

    // 10. Fix up instance.ctx pointers that were created with stack-local ctx_data
    // The window_instance and document_instance have ctx pointing to stack-local ctx_data,
    // but now ctx_data has been copied into the heap-allocated child_entry.
    // Update them to point to the stable location.
    window_instance.ctx = &child_entry.runtime_ctx;
    document_instance.ctx = &child_entry.runtime_ctx;

    // 10b. Initialize document with standard HTML structure (html > head + body)
    // Per HTML spec, a new browsing context's document should have this structure
    // to ensure document.body, document.head, and document.documentElement work.
    // NOTE: This must happen AFTER the context is registered in the map (step 9)
    // because element creation uses wrapper cache which needs context lookup.
    initializeIframeDocumentStructure(allocator, &child_entry.runtime_ctx, document_instance);

    // 11. Link to parent's children list
    try parent_entry.children.append(allocator, child_entry);

    return child_entry;
}

/// Destroy a child context and clean up resources
///
/// This recursively destroys all child contexts, removes from parent's
/// children list, cleans up the realm and runtime context, and removes
/// from the context manager.
///
/// Thread safety: Thread-local, no synchronization needed
///
/// Arguments:
/// - entry: The context entry to destroy
/// - allocator: Allocator used for the entry
pub fn destroyChildContext(entry: *ContextEntry, allocator: std.mem.Allocator) void {
    const state = &(manager_state orelse return);

    // 0. Skip if we're in the middle of full teardown (context_manager.deinit)
    // This happens when wrapper_cache.deinit() triggers onObjectFreed for iframes,
    // which then tries to clean up child contexts. Since deinit() already cleans
    // up all contexts, we don't need to do it again here.
    if (state.is_tearing_down) return;

    // 0b. Check if already removed (guard against double-cleanup)
    const raw_addr = v8.v8_Context_GetRawAddress(entry.v8_ctx);
    if (raw_addr == null) return;
    const key = @intFromPtr(raw_addr);
    if (state.contexts.get(key) == null) {
        // Already cleaned up, nothing to do
        return;
    }

    // 1. Recursively destroy all children first
    // Make a copy of items since we're modifying while iterating
    var children_copy: std.ArrayListUnmanaged(*ContextEntry) = .{};
    children_copy.appendSlice(allocator, entry.children.items) catch {};

    for (children_copy.items) |child| {
        destroyChildContext(child, allocator);
    }
    children_copy.deinit(allocator);

    // 2. Remove from parent's children list
    if (entry.parent_entry) |parent| {
        for (parent.children.items, 0..) |child, i| {
            if (child == entry) {
                _ = parent.children.swapRemove(i);
                break;
            }
        }
    }

    // 3. Clean up our children list
    entry.children.deinit(allocator);

    // 4. Clean up owned resources (key already computed at top of function)
    if (entry.owns_context) {
        var ctx_data = entry.runtime_ctx;

        // Clean up Window instance and its Document FIRST
        // This cleans up the DOM tree in proper order (parent before children),
        // and each Node.deinit removes itself from the wrapper cache to prevent double-free.
        // This MUST happen before wrapper cache cleanup to avoid use-after-free:
        // if wrapper cache iterates children before parents, it would free child
        // nodes, then when parent.deinit walks first_child, those nodes are already freed.
        if (entry.window_instance) |window| {
            const interfaces = @import("interfaces");
            const WindowImpl = @import("impls").Window;

            // Clean up Document instance first (owns the entire DOM tree)
            if (WindowImpl.getInternal(window)) |internal| {
                if (internal.document) |doc| {
                    interfaces.Document.deinit(doc);
                    internal.document = null;
                }
            }

            interfaces.Window.deinit(window);
        }

        // Clean up V8 wrapper cache WITH callbacks
        // Now safe to call deinit() because:
        // 1. DOM nodes already removed themselves from cache via Node.deinit
        // 2. Remaining entries are non-DOM objects (AbortController, etc.)
        // 3. These need their deinit called to free InternalState
        if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
            const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
            const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
            cache_ptr.deinit();
            ctx_data.getAllocator().destroy(cache_ptr);
            ctx_data.clearV8WrapperCacheStorage();
        }

        // Clean up realm
        if (entry.realm) |realm| {
            realm.deinit();
        }

        ctx_data.deinit();
    }

    // 6. Remove from context map and free the heap-allocated entry
    _ = state.contexts.remove(key);
    state.allocator.destroy(entry);
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
/// Thread safety: Thread-local, no synchronization needed
pub fn getWindowForContext(v8_ctx: *v8.Context) ?*runtime.Instance {
    const state = &(manager_state orelse return null);

    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return null;
    const key = @intFromPtr(raw_addr);

    if (state.contexts.get(key)) |entry| {
        return entry.window_instance;
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

    // 4. Populate Zig-side template registry (interfaces already in snapshot)
    interface_bindings.registerAllTemplatesOnly(isolate);

    // 5. Reinstall accessor callbacks after snapshot restore.
    // NOTE: The optimization from whatwg-8oip3 that skipped this was WRONG.
    // NEW ARCHITECTURE (whatwg-izjpz): On-demand template creation
    // With minimal snapshot (only core interfaces), non-core interface templates are
    // created fresh on-demand with all accessors correctly installed from the start.
    // No reinstallation needed - eliminates the prototype identity bug.
    std.debug.print("[HYDRATE-WINDOW] Using on-demand template architecture (no accessor reinstall needed)\n", .{});

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
    // Use comptime-generated registry which has ALL interfaces
    const wrapper_type_info_registry_3 = @import("wrapper_type_info_registry.zig");
    v8.v8_Object_SetAlignedPointerInInternalField(global, 0, @ptrCast(window_instance));
    if (wrapper_type_info_registry_3.getWrapperTypeInfoByName("Window")) |type_info| {
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

    std.debug.print("[HYDRATE-WORKER] hydrateWorkerContext called, isolate={*}, context={*}\n", .{ isolate, v8_ctx });

    // 1. Initialize context manager (if not already initialized)
    init(allocator) catch |err| {
        if (err != error.AlreadyInitialized) {
            return err;
        }
    };

    // 2. Register context with context manager
    const runtime_ctx = try getOrCreate(v8_ctx, allocator);

    // 3. Populate Zig-side template registry (interfaces already in snapshot)
    std.debug.print("[HYDRATE-WORKER] Calling registerAllTemplatesOnly...\n", .{});
    interface_bindings.registerAllTemplatesOnly(isolate);

    // 4. Reinstall accessor callbacks after snapshot restore.
    // NOTE: The optimization from whatwg-8oip3 that skipped this was WRONG.
    // V8 snapshots do NOT preserve native accessor callbacks even with external references.
    // The "on-demand template architecture" assumption was ALSO WRONG for events:
    // - Events like MessageEvent are created in the main thread and passed to workers
    // - Their prototypes come from the snapshot with disconnected accessor callbacks
    // - Even if templates are created on-demand, global.Constructor.prototype is stale
    // FIX (whatwg-gy5zk): Reinstall ALL accessor callbacks for ALL interfaces.
    // This ensures Event.data, MessageEvent.data, ErrorEvent.message, etc. all work.
    std.debug.print("[HYDRATE-WORKER] Reinstalling accessor callbacks on ALL interface prototypes...\n", .{});
    interface_bindings.reinstallAllAccessorCallbacks(isolate, v8_ctx);
    std.debug.print("[HYDRATE-WORKER] Accessor callbacks reinstalled\n", .{});

    // 5. Install lazy constructors on global object
    // V8 snapshots don't preserve lazy data properties on the global proxy.
    // We must re-install them after context restoration (matches Chromium's pattern).
    // Without this, interfaces like URL, URLSearchParams, etc. are not available.
    const global_constructor_handler = @import("global_constructor_handler.zig");
    global_constructor_handler.installLazyConstructorsOnGlobal(v8_ctx);
    std.debug.print("[HYDRATE-WORKER] Lazy constructors installed on worker global\n", .{});

    std.debug.print("[HYDRATE-WORKER] hydrateWorkerContext complete\n", .{});

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
