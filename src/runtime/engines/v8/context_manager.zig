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
//!     const instance = Interface.call_constructor(allocator, ctx) catch return;
//! }
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const runtime = @import("runtime");
const V8EventLoop = @import("event_loop.zig").V8EventLoop;
const v8_engine = @import("engine.zig");

/// Context mapping entry
const ContextEntry = struct {
    /// V8 context pointer (key)
    v8_ctx: *v8.Context,

    /// Runtime context data (owned)
    runtime_ctx: runtime.ContextData,

    /// Whether this entry owns the runtime context
    /// (and should deinit it when removed)
    owns_context: bool,

    /// V8 event loop with timer support (owned if owns_context is true)
    event_loop: ?*V8EventLoop,
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

        // Deinit all owned runtime contexts
        var it = state.contexts.valueIterator();
        while (it.next()) |entry| {
            if (entry.owns_context) {
                var ctx_data = entry.runtime_ctx;

                // Clean up V8 wrapper cache
                if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
                    const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
                    cache_ptr.deinit();
                    ctx_data.getAllocator().destroy(cache_ptr);
                }

                // Clean up V8 event loop (must be done before context deinit)
                if (entry.event_loop) |ev_loop| {
                    ev_loop.deinit();
                    ctx_data.getAllocator().destroy(ev_loop);
                }

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
        if (kv.value.owns_context) {
            var ctx_data = kv.value.runtime_ctx;

            // Clean up V8 wrapper cache before deinit
            if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
                const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
                const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
                cache_ptr.deinit();
                ctx_data.getAllocator().destroy(cache_ptr);
                ctx_data.clearV8WrapperCacheStorage();
            }

            // Clean up V8 event loop
            if (kv.value.event_loop) |ev_loop| {
                ev_loop.deinit();
                ctx_data.getAllocator().destroy(ev_loop);
            }

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
