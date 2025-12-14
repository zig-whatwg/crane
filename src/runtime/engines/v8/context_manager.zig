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

/// Manager state (thread-local)
const ManagerState = struct {
    /// Allocator for internal structures
    allocator: std.mem.Allocator,

    /// Map from V8 context pointer to runtime context
    /// Key: usize (casted from *v8.Context)
    /// Value: ContextEntry
    contexts: std.AutoHashMap(usize, ContextEntry),

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
        .contexts = std.AutoHashMap(usize, ContextEntry).init(allocator),
        .default_allocator = allocator,
    };
}

/// Deinitialize the context manager and free all contexts
///
/// Cleans up all runtime contexts that were created by the manager.
/// After calling deinit(), init() must be called again before use.
///
/// Thread safety: Thread-local, no synchronization needed
pub fn deinit() void {
    if (manager_state) |*state| {
        const WrapperCache = @import("wrapper_cache.zig").WrapperCache;

        // Set teardown flag to prevent nested cleanup attempts
        // When wrapper_cache.deinit() triggers onObjectFreed for iframes,
        // the iframe cleanup will try to call destroyChildContext. We need
        // to skip those calls since we're already tearing everything down.
        state.is_tearing_down = true;

        // Clean up Intl registries (safety net for entries not GC'd)
        // This must be done before contexts are destroyed since weak callbacks
        // may still reference registry data
        intl_binding.deinitAllRegistries();

        // Deinit all owned runtime contexts
        // Note: The order doesn't matter for cleanup because we skip onObjectFreed
        // during teardown (is_tearing_down flag prevents nested calls).
        var it = state.contexts.valueIterator();
        while (it.next()) |entry| {
            if (entry.owns_context) {
                var ctx_data = entry.runtime_ctx;

                // Clean up V8 wrapper cache
                // Note: During teardown, wrapper_cache.deinit() skips onObjectFreed
                // to avoid use-after-free issues with cross-context references.
                if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
                    const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
                    cache_ptr.deinitWithoutCallbacks();
                    ctx_data.getAllocator().destroy(cache_ptr);
                }

                // Clean up V8 event loop (must be done before context deinit)
                if (entry.event_loop) |ev_loop| {
                    ev_loop.deinit();
                    ctx_data.getAllocator().destroy(ev_loop);
                }

                // Clean up realm
                if (entry.realm) |realm| {
                    realm.deinit();
                }

                // Clean up children list (entries themselves are in the map)
                var children = entry.children;
                children.deinit(entry.allocator);

                ctx_data.deinit();
            }
        }

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
    if (state.contexts.getPtr(key)) |entry| {
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

    // Store in map (no event loop owned)
    try state.contexts.put(key, ContextEntry{
        .v8_ctx = v8_ctx,
        .runtime_ctx = ctx_data,
        .owns_context = true,
        .event_loop = null, // We don't own the external event loop
        .realm = null,
        .parent_entry = null,
        .children = .{},
        .allocator = allocator,
    });

    const entry = state.contexts.getPtr(key).?;
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
    const entry = state.contexts.getPtr(key) orelse return error.ContextNotFound;

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
    if (state.contexts.getPtr(key)) |entry| {
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

    // Register dynamic import handler for this isolate
    // This enables import() expressions in JavaScript per HTML spec HostImportModuleDynamically
    if (isolate) |iso| {
        v8_engine.setDynamicImportHandler(iso, .{
            .callback = handleDynamicImport,
            .context = @ptrCast(v8_ctx),
        });
    }

    // Store in map
    try state.contexts.put(key, ContextEntry{
        .v8_ctx = v8_ctx,
        .runtime_ctx = ctx_data,
        .owns_context = true,
        .event_loop = event_loop_ptr,
        .realm = null,
        .parent_entry = null,
        .children = .{},
        .allocator = allocator,
    });

    // Return pointer to context data in the hash map
    // This is safe because AutoHashMap doesn't move values on rehash
    const entry = state.contexts.getPtr(key).?;
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

    if (state.contexts.getPtr(key)) |entry| {
        return &entry.runtime_ctx;
    }

    return null;
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

    // Store in map (context not owned)
    try state.contexts.put(key, ContextEntry{
        .v8_ctx = v8_ctx,
        .runtime_ctx = ctx.*, // Copy the context data
        .owns_context = false, // Don't deinit this one
        .event_loop = null, // Registered contexts don't have event loop
        .realm = null,
        .parent_entry = null,
        .children = .{},
        .allocator = state.allocator,
    });
}

/// Remove a runtime context for a V8 context
///
/// If the context manager owns the runtime context, it will be deinitialized.
/// If the context was registered via register(), it will NOT be deinitialized.
///
/// Thread safety: Thread-local, no synchronization needed
pub fn removeContext(v8_ctx: *v8.Context) void {
    const state = &(manager_state orelse return);

    const key = @intFromPtr(v8_ctx);

    if (state.contexts.fetchRemove(key)) |kv| {
        var entry = kv.value;
        if (entry.owns_context) {
            var ctx_data = entry.runtime_ctx;

            // Clean up V8 wrapper cache before deinit
            if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
                const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
                const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
                cache_ptr.deinit();
                ctx_data.getAllocator().destroy(cache_ptr);
                ctx_data.clearV8WrapperCacheStorage();
            }

            // Clean up V8 event loop
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
    while (it.next()) |entry| {
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

    const entry = state.contexts.getPtr(key) orelse {
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
    const dom_type_info = @import("dom_type_info.zig");
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
};

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
    const parent_entry = state.contexts.getPtr(parent_key) orelse return null;

    // 1. Create new global template
    const global_template = v8.v8_ObjectTemplate_New(isolate);
    v8.v8_ObjectTemplate_SetInternalFieldCount(global_template, 2);
    v8.v8_ObjectTemplate_SetIndexedPropertyHandlerFull(
        global_template,
        windowIndexedPropertyGetter,
        windowIndexedPropertyQuery,
        windowIndexedPropertyEnumerator,
        null,
    );

    // 2. Create new V8 context
    const child_context = v8.v8_Context_NewWithGlobalTemplate(
        isolate,
        global_template,
    ) orelse return null;

    const child_raw_addr = v8.v8_Context_GetRawAddress(child_context) orelse return null;
    const child_key = @intFromPtr(child_raw_addr);

    // 2b. Set security token to match parent context (same-origin for iframes)
    if (v8.v8_Context_GetSecurityToken(parent_context)) |parent_token| {
        v8.v8_Context_SetSecurityToken(child_context, parent_token);
    }

    // 3. Enter the new context for initialization
    v8.v8_Context_Enter(child_context);
    defer v8.v8_Context_Exit(child_context);

    // 4. Initialize all interface bindings
    interface_bindings.initializeBindings(isolate, child_context);

    // 4b. Set global object's prototype to Window.prototype
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

    // 5. Create realm
    const realm = runtime.Realm.init(allocator, .{
        .v8_context = @ptrCast(child_context),
        .isolate = @ptrCast(isolate),
        .context_type = .window,
        .global_object = @ptrCast(v8.v8_Context_Global(child_context)),
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

    // 9. Bind Window to global (internal fields + wrapper cache)
    const dom_type_info = @import("dom_type_info.zig");
    v8.v8_Object_SetAlignedPointerInInternalField(global, 0, @ptrCast(window_instance));
    if (dom_type_info.getTypeInfoByName("Window")) |type_info| {
        v8.v8_Object_SetAlignedPointerInInternalField(global, 1, @ptrCast(@constCast(type_info)));
    }
    WindowImpl.setBoundV8Global(window_instance, @ptrCast(global));
    cache_ptr.set(window_instance, global, isolate) catch {};

    // 10. CRITICAL: Set this Window as active_window on the EXISTING child browsing context
    // This is the key difference from createChildContext - we use the existing BC
    // Use the helper function exported from Window impl to set the active window
    @import("impls").Window.setActiveWindowOnBrowsingContext(child_bc_opaque, @ptrCast(window_instance));

    // 11. Store in context map
    state.contexts.put(child_key, ContextEntry{
        .v8_ctx = child_context,
        .runtime_ctx = ctx_data,
        .owns_context = true,
        .event_loop = null,
        .realm = realm,
        .parent_entry = parent_entry,
        .children = .{},
        .allocator = allocator,
        .window_instance = window_instance,
    }) catch return null;

    // 12. Link to parent's children list
    const child_entry = state.contexts.getPtr(child_key).?;
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
) callconv(.c) void {
    const WindowImpl = @import("impls").Window;
    const template_registry = @import("template_registry.zig");
    const conv = @import("conversions.zig");

    const isolate = info.getIsolate();
    const v8_context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

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
        return;
    }

    // Safety check for use-after-free patterns
    const ptr_as_int = @intFromPtr(instance_ptr);
    const poison_pattern_aa: usize = 0xaaaaaaaaaaaaaaaa;
    const poison_pattern_dead: usize = 0xdeaddeaddeaddead;
    if (ptr_as_int == poison_pattern_aa or ptr_as_int == poison_pattern_dead or
        (ptr_as_int & 0xFFFF000000000000) == 0xaaaa000000000000)
    {
        return;
    }

    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));

    // First try to get an existing child Window via Window.call_item
    var result = WindowImpl.call_item(instance, index) catch {
        // Error - let V8 handle normal lookup
        return;
    };

    // If result is null, check if we need to lazily create the child context
    // This happens when an iframe is in the DOM but contentWindow hasn't been accessed yet
    if (result == null) {
        const internal = WindowImpl.getInternal(instance) orelse return;
        const children = internal.browsing_context.children.items;

        // Check if the index is valid (child browsing context exists)
        if (index < children.len) {
            const child_bc = children[index];

            // Child browsing context exists but no Window - create it
            if (child_bc.getActiveWindow() == null) {
                // Get the allocator from the context entry
                const entry = getEntry(v8_context) orelse return;

                // Create a V8 context and Window for the existing BrowsingContext
                result = createWindowForExistingBrowsingContext(
                    v8_context,
                    isolate,
                    child_bc,
                    entry.allocator,
                );
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
            return;
        };
        info.setReturnValue(@ptrCast(wrapped));
    }
    // If result is null (out of bounds), don't set a return value
    // This lets V8 continue with normal property lookup (returns undefined)
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

    // Create array of indices
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
    const parent_entry = state.contexts.getPtr(parent_key) orelse return error.ParentNotFound;

    // 1. Create new global template
    // We use a plain ObjectTemplate here because using Window's full FunctionTemplate
    // causes V8 to crash with duplicate property conflicts. Instead, we'll set the
    // prototype chain after context creation.
    const global_template = v8.v8_ObjectTemplate_New(options.isolate);

    // Set internal field count for Window binding (2 fields: impl pointer + destructor type)
    v8.v8_ObjectTemplate_SetInternalFieldCount(global_template, 2);

    // 1b. Set up indexed property handler for frames[index] access
    // Per HTML spec §7.4.3.1 (WindowProxy [[GetOwnProperty]]):
    // - Numeric indices return child browsing context Windows
    // - This enables `iframe.contentWindow[0]` to access nested iframes
    v8.v8_ObjectTemplate_SetIndexedPropertyHandlerFull(
        global_template,
        windowIndexedPropertyGetter,
        windowIndexedPropertyQuery,
        windowIndexedPropertyEnumerator,
        null, // descriptor callback - not needed for basic access
    );

    // 2. Create new V8 context with the global template
    const child_context = v8.v8_Context_NewWithGlobalTemplate(
        options.isolate,
        global_template,
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

    // 4. Initialize all interface bindings in new context
    // This registers all WebIDL interfaces as global constructors
    const interface_bindings = @import("interface_bindings.zig");
    interface_bindings.initializeBindings(options.isolate, child_context);

    // 4b. Set global object's prototype to Window.prototype
    // This is required for cross-realm support: when JavaScript accesses
    // `iframe.contentWindow.name`, it needs to find the `name` getter from
    // Window.prototype in the prototype chain.
    const global = v8.v8_Context_Global(child_context) orelse return error.GlobalNotFound;

    // Get Window constructor from the global scope
    const window_key = v8.v8_String_NewFromUtf8(options.isolate, "Window", 6);
    if (window_key) |wk| {
        if (v8.v8_Object_Get(global, child_context, @ptrCast(wk))) |window_ctor| {
            // Get Window.prototype
            const proto_key = v8.v8_String_NewFromUtf8(options.isolate, "prototype", 9);
            if (proto_key) |pk| {
                if (v8.v8_Object_Get(@ptrCast(window_ctor), child_context, @ptrCast(pk))) |window_proto| {
                    // Set the global object's prototype to Window.prototype
                    // This makes Window properties (like `name`) accessible on the global
                    // Use SetPrototypeV2 which works properly with global objects
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
    interface_bindings.Window.registerPropertiesAsOwnOnObject(
        options.isolate,
        child_context,
        global,
    );

    // 5. Create realm for new context
    const realm = try runtime.Realm.init(allocator, .{
        .v8_context = @ptrCast(child_context),
        .isolate = @ptrCast(options.isolate),
        .context_type = options.context_type,
        .global_object = @ptrCast(v8.v8_Context_Global(child_context)),
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

    // 8b. Link child Window's browsing context to parent Window's browsing context
    // This enables `window.frames[0]` to work by adding the child to parent's children list.
    // Without this, the child Window's browsing context is orphaned (created as top-level).
    if (parent_entry.window_instance) |parent_window| {
        const WindowImpl = @import("impls").Window;

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

    // 9. Store in map
    // Note: We use parent_key here instead of parent_entry pointer because the put()
    // below may cause the HashMap to rehash, invalidating any previously obtained pointers.
    try state.contexts.put(child_key, ContextEntry{
        .v8_ctx = child_context,
        .runtime_ctx = ctx_data,
        .owns_context = true,
        .event_loop = null, // Child doesn't own event loop (inherits from parent or none)
        .realm = realm,
        .parent_entry = null, // Will be set below after rehash-safe lookup
        .children = .{},
        .allocator = allocator,
        .window_instance = window_instance,
    });

    // 10. Get pointer to entry in map
    const child_entry = state.contexts.getPtr(child_key).?;

    // 10b. CRITICAL: Update Window's context pointer to the entry's runtime_ctx
    // The window_instance was created with a pointer to the stack-local ctx_data.
    // Now that ctx_data has been copied into the ContextEntry, we need to update
    // the Window's ctx to point to the stable location in the map.
    // Without this fix, Window.get_name() crashes when accessing instance.ctx.allocator
    // because instance.ctx points to freed stack memory.
    window_instance.ctx = &child_entry.runtime_ctx;

    // 11. Re-fetch parent entry pointer after put() to ensure it's still valid
    // (HashMap may have rehashed during put(), invalidating previous pointers)
    const fresh_parent_entry = state.contexts.getPtr(parent_key).?;

    // 12. Set parent_entry now that we have valid pointers
    child_entry.parent_entry = fresh_parent_entry;

    // 13. Link to parent's children list
    try fresh_parent_entry.children.append(allocator, child_entry);

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

        // Clean up V8 wrapper cache (must be before Window deinit)
        if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
            const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
            const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
            cache_ptr.deinit();
            ctx_data.getAllocator().destroy(cache_ptr);
            ctx_data.clearV8WrapperCacheStorage();
        }

        // Clean up Window instance (must be after wrapper cache cleanup)
        if (entry.window_instance) |window| {
            const interfaces = @import("interfaces");
            interfaces.Window.deinit(window);
        }

        // Clean up realm
        if (entry.realm) |realm| {
            realm.deinit();
        }

        ctx_data.deinit();
    }

    // 6. Remove from context map
    _ = state.contexts.remove(key);
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

    if (state.contexts.getPtr(key)) |entry| {
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

    return state.contexts.getPtr(key);
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

    if (state.contexts.getPtr(key)) |entry| {
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

    if (state.contexts.getPtr(key)) |entry| {
        // Free existing realm if any
        if (entry.realm) |old_realm| {
            old_realm.deinit();
        }
        entry.realm = realm;
    } else {
        return error.ContextNotFound;
    }
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
