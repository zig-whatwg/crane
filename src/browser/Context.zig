//! Context - V8 Context per Navigation
//!
//! This module manages a V8 context (JavaScript execution environment) for a single
//! page navigation. A new context is created for each navigation while the isolate
//! is reused.
//!
//! ## Responsibilities
//!
//! - Create V8 context within existing isolate
//! - Register browser globals (window, document, navigator, etc.)
//! - Register WebIDL bindings
//! - Execute scripts and handle events
//!
//! ## Performance
//!
//! Context creation is cheap (~1-5ms) compared to isolate creation (~50-100ms).
//! This enables efficient WPT test execution.
//!
//! ## Specification References
//!
//! - HTML Standard: Browsing contexts https://html.spec.whatwg.org/multipage/document-sequences.html
//! - HTML Standard: Window object https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-window-object

const std = @import("std");
const v8 = @import("v8");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const namespaces = @import("namespaces");

const callback_registry = v8.callback_registry;
const storage_mod = @import("storage/Storage.zig");
const Storage = storage_mod.Storage;
const navigation = @import("navigation.zig");
const context_manager = v8.context_manager;
const impls = @import("impls");

// Timer support
const TimerInterface = runtime.TimerInterface;
const TimerId = runtime.TimerId;
const TimerCallback = runtime.TimerCallback;
const typed_callback = runtime.typed_callback;
const SelfContainedWorkCallback = typed_callback.SelfContainedWorkCallback;

// ============================================================================
// Thread-local storage for timer interface (mirrors browser_context.zig pattern)
// ============================================================================

threadlocal var current_timer_interface: ?TimerInterface = null;
threadlocal var current_allocator: ?std.mem.Allocator = null;
threadlocal var timer_contexts: ?std.AutoHashMap(TimerId, *V8TimerCallback) = null;

/// Set the current timer interface for V8 callbacks
pub fn setTimerInterface(timer: TimerInterface, allocator: std.mem.Allocator) void {
    current_timer_interface = timer;
    current_allocator = allocator;
    // Initialize timer contexts map if needed
    if (timer_contexts == null) {
        timer_contexts = std.AutoHashMap(TimerId, *V8TimerCallback).init(allocator);
    }
}

/// Get the current timer interface (for V8 callbacks)
pub fn getTimerInterface() ?TimerInterface {
    return current_timer_interface;
}

/// Clear the timer interface reference and clean up ALL pending timer contexts
/// This properly cancels libuv timers to prevent handle accumulation
pub fn clearTimerInterface() void {
    // Clean up any remaining timer contexts (both one-shot and intervals)
    if (timer_contexts) |*map| {
        var iter = map.iterator();
        while (iter.next()) |entry| {
            const wrapper = entry.value_ptr.*;
            // CRITICAL: Set destroyed flag BEFORE any cleanup to prevent use-after-free.
            // The libuv uv_close() is async, so a timer callback could still fire
            // between clearTimeout() and destroy(). The destroyed flag ensures the
            // callback handler will early-exit instead of accessing freed memory.
            wrapper.getData().destroyed = true;
            // Cancel the timer at the libuv level to prevent callback from firing
            // and to properly clean up the libuv timer handle
            if (current_timer_interface) |timer| {
                timer.clearTimeout(wrapper.getData().current_timer_id);
            }
            wrapper.destroy();
        }
        map.deinit();
        timer_contexts = null;
    }

    current_timer_interface = null;
    current_allocator = null;
}

/// Clear ALL pending timer contexts but keep the timer interface
/// This is used during test isolation to cancel timers without tearing down the interface
pub fn clearPendingTimers() void {
    if (timer_contexts) |*map| {
        var iter = map.iterator();
        while (iter.next()) |entry| {
            const wrapper = entry.value_ptr.*;
            // CRITICAL: Set destroyed flag BEFORE any cleanup to prevent use-after-free.
            // The libuv uv_close() is async, so a timer callback could still fire
            // between clearTimeout() and destroy(). The destroyed flag ensures the
            // callback handler will early-exit instead of accessing freed memory.
            wrapper.getData().destroyed = true;
            // Cancel the timer at the libuv level
            if (current_timer_interface) |timer| {
                timer.clearTimeout(wrapper.getData().current_timer_id);
            }
            // Destroy the timer wrapper
            wrapper.destroy();
        }
        map.clearRetainingCapacity();
    }
}

/// Register a timer context for cleanup tracking (both one-shot and intervals)
fn registerTimerContext(timer_id: TimerId, wrapper: *V8TimerCallback) void {
    if (timer_contexts) |*map| {
        map.put(timer_id, wrapper) catch |err| {
            // If we can't track the timer, we must destroy it to prevent leaks
            std.debug.print("Warning: Failed to register timer context {}: {}\n", .{ timer_id, err });
            wrapper.destroy();
        };
    } else {
        // timer_contexts is null - this shouldn't happen if setTimerInterface was called
        // Destroy the context to prevent memory leak
        std.debug.print("Warning: timer_contexts is null, destroying untracked timer {}\n", .{timer_id});
        wrapper.destroy();
    }
}

/// Unregister a timer context (cancels and destroys it)
fn unregisterTimerContext(timer_id: TimerId) void {
    if (timer_contexts) |*map| {
        if (map.fetchRemove(timer_id)) |kv| {
            const wrapper = kv.value;
            const data = wrapper.getData();
            // CRITICAL: Set destroyed flag BEFORE any cleanup to prevent use-after-free.
            // The libuv uv_close() is async, so a timer callback could still fire
            // between clearTimeout() and destroy(). The destroyed flag ensures the
            // callback handler will early-exit instead of accessing freed memory.
            data.destroyed = true;
            // Mark as cancelled so interval callbacks know to stop rescheduling
            data.cancelled = true;
            // Cancel the timer at the libuv level to prevent callback from firing
            if (current_timer_interface) |timer| {
                timer.clearTimeout(timer_id);
            }
            // Destroy the wrapper immediately - the timer won't fire anymore
            wrapper.destroy();
        }
    }
}

// ============================================================================
// V8 Timer Context Types
// ============================================================================

/// V8 Timer Context Data
///
/// Holds the V8 function reference and metadata for timer/interval callbacks.
/// Uses GlobalHandle to prevent V8 GC from collecting the callback function
/// before the timer fires.
const V8TimerContextData = struct {
    /// GlobalHandle to the V8 function (GC-protected!)
    callback_handle: v8.GlobalHandle,
    /// V8 isolate
    isolate: *v8.ffi.Isolate,
    /// Whether this is an interval (repeating) timer - affects cleanup
    is_interval: bool,
    /// For intervals: the delay in ms for rescheduling
    interval_delay_ms: u64 = 0,
    /// For intervals: the current timer ID (updated on each reschedule)
    current_timer_id: TimerId = 0,
    /// For intervals: whether the interval has been cancelled
    cancelled: bool = false,
    /// Flag to prevent use-after-free when timer fires during cleanup.
    /// Set to true BEFORE destroy() is called. Timer handlers check this
    /// flag and early-exit if true, preventing access to freed memory.
    /// This addresses the race condition where libuv's uv_close() is async
    /// but we destroy the wrapper memory synchronously.
    destroyed: bool = false,
};

/// Type-safe timer callback wrapper for V8 timer contexts.
///
/// Uses SelfContainedWorkCallback to bundle the callback function and context data
/// together, providing compile-time type safety and eliminating manual
/// anyopaque casts in callback functions. The work callback variant stores
/// the allocator internally for no-argument destroy().
const V8TimerCallback = SelfContainedWorkCallback(V8TimerContextData);

/// Create a new V8 timer context wrapper
fn createV8TimerContext(allocator: std.mem.Allocator, isolate: *v8.ffi.Isolate, callback_value: *v8.ffi.Value, is_interval: bool) !*V8TimerCallback {
    // Verify it's a function
    if (!v8.ffi.v8_Value_IsFunction(callback_value)) {
        return error.NotAFunction;
    }

    // Create a GlobalHandle to prevent V8 GC from collecting the callback
    const callback_handle = v8.GlobalHandle.create(isolate, callback_value) orelse {
        return error.FailedToCreateGlobalHandle;
    };

    const callback_fn = if (is_interval) &v8IntervalHandler else &v8TimerHandler;
    return try V8TimerCallback.create(
        allocator,
        callback_fn,
        .{
            .callback_handle = callback_handle,
            .isolate = isolate,
            .is_interval = is_interval,
        },
    );
}

/// Handler function for one-shot timer callbacks (invoked via SelfContainedCallback trampoline)
fn v8TimerHandler(data: *V8TimerContextData) void {
    // CRITICAL: Check destroyed flag FIRST to prevent use-after-free.
    // If the timer context was destroyed during cleanup (clearTimerInterface,
    // clearPendingTimers, or unregisterTimerContext), the memory may be freed
    // but this callback could still fire due to libuv's async uv_close().
    if (data.destroyed) return;

    // Unregister from timer_contexts map before destroying (prevents double-free on deinit)
    if (timer_contexts) |*map| {
        _ = map.remove(data.current_timer_id);
    }

    const isolate = data.isolate;
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    const global = v8.ffi.v8_Context_Global(context) orelse return;

    // Enter the context before making V8 calls
    v8.ffi.v8_Context_Enter(context);
    defer v8.ffi.v8_Context_Exit(context);

    // Get the callback function from GlobalHandle (prevents GC issues)
    const callback_value = data.callback_handle.get(isolate) orelse return;

    // Verify the callback is still a function (safety check)
    if (!v8.ffi.v8_Value_IsFunction(callback_value)) {
        data.callback_handle.dispose();
        const wrapper: *V8TimerCallback = @fieldParentPtr("data", data);
        wrapper.destroy();
        return;
    }

    const callback_fn: *v8.ffi.Function = @ptrCast(callback_value);

    // Invoke the V8 function
    var empty_args: [1]*v8.ffi.Value = undefined;
    _ = v8.ffi.v8_Function_Call(callback_fn, context, @ptrCast(global), 0, &empty_args);

    // Run microtasks after the timer callback (per event loop semantics)
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

    // Dispose the GlobalHandle before destroying the wrapper
    data.callback_handle.dispose();

    // Destroy the wrapper - this is a one-shot timer, so clean up after execution
    // Get the wrapper pointer from the data pointer (data is embedded in SelfContainedCallback)
    const wrapper: *V8TimerCallback = @fieldParentPtr("data", data);
    wrapper.destroy();
}

/// Handler function for interval callbacks (invoked via SelfContainedCallback trampoline)
fn v8IntervalHandler(data: *V8TimerContextData) void {
    // CRITICAL: Check destroyed flag FIRST to prevent use-after-free.
    // If the timer context was destroyed during cleanup (clearTimerInterface,
    // clearPendingTimers, or unregisterTimerContext), the memory may be freed
    // but this callback could still fire due to libuv's async uv_close().
    if (data.destroyed) return;

    // Check if interval was cancelled
    if (data.cancelled) {
        if (timer_contexts) |*map| {
            _ = map.remove(data.current_timer_id);
        }
        // Dispose the GlobalHandle when interval is cancelled
        data.callback_handle.dispose();
        return;
    }

    const isolate = data.isolate;
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    const global = v8.ffi.v8_Context_Global(context) orelse return;

    // Enter the context before making V8 calls
    v8.ffi.v8_Context_Enter(context);
    defer v8.ffi.v8_Context_Exit(context);

    // Get the callback function from GlobalHandle (prevents GC issues)
    const callback_value = data.callback_handle.get(isolate) orelse return;

    // Verify the callback is still a function (safety check)
    if (!v8.ffi.v8_Value_IsFunction(callback_value)) {
        data.callback_handle.dispose();
        return;
    }

    const callback_fn: *v8.ffi.Function = @ptrCast(callback_value);

    // Invoke the V8 function
    var empty_args: [1]*v8.ffi.Value = undefined;
    _ = v8.ffi.v8_Function_Call(callback_fn, context, @ptrCast(global), 0, &empty_args);

    // Run microtasks after the timer callback
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

    // Reschedule the interval if not cancelled
    if (!data.cancelled) {
        if (getTimerInterface()) |timer| {
            // Get the wrapper pointer from the data pointer
            const wrapper: *V8TimerCallback = @fieldParentPtr("data", data);

            const new_timer_id = timer.setTimeout(
                data.interval_delay_ms,
                V8TimerCallback.getTrampolineCallback(),
                wrapper.eraseForFFI(),
            );
            if (new_timer_id != 0) {
                // Update the timer ID for potential clearInterval calls
                const old_id = data.current_timer_id;
                data.current_timer_id = new_timer_id;
                // Update the timer context map with new ID
                if (timer_contexts) |*map| {
                    _ = map.remove(old_id);
                    map.put(new_timer_id, wrapper) catch {};
                }
            } else {
                // Failed to reschedule, clean up
                if (timer_contexts) |*map| {
                    _ = map.remove(data.current_timer_id);
                }
                wrapper.destroy();
            }
        } else {
            // No timer interface, clean up
            if (timer_contexts) |*map| {
                _ = map.remove(data.current_timer_id);
            }
            const wrapper: *V8TimerCallback = @fieldParentPtr("data", data);
            wrapper.destroy();
        }
    } else {
        // Cancelled, clean up
        if (timer_contexts) |*map| {
            _ = map.remove(data.current_timer_id);
        }
        const wrapper: *V8TimerCallback = @fieldParentPtr("data", data);
        wrapper.destroy();
    }
}

/// Context type for determining which globals to register
pub const ContextType = enum {
    /// Window context (for HTML pages)
    window,
    /// Dedicated worker context
    worker,
    /// Shared worker context
    shared_worker,
    /// Service worker context
    service_worker,
    /// AudioWorklet context (Web Audio API)
    audio_worklet,
    /// PaintWorklet context (CSS Paint API)
    paint_worklet,
    /// AnimationWorklet context (CSS Animation Worklet)
    animation_worklet,
    /// LayoutWorklet context (CSS Layout API)
    layout_worklet,
    /// ShadowRealm context (TC39 Stage 3 proposal)
    shadow_realm,
    /// SharedStorageWorklet context (Shared Storage API)
    shared_storage_worklet,

    /// Convert to SnapshotContextIndex for multi-context snapshot selection.
    /// Each context type maps to a pre-created snapshot context with the
    /// appropriate global scope interfaces already registered.
    pub fn toSnapshotIndex(self: ContextType) v8.SnapshotContextIndex {
        return switch (self) {
            .window => .window,
            .worker => .dedicated_worker,
            .shared_worker => .shared_worker,
            .service_worker => .service_worker,
            .audio_worklet => .audio_worklet,
            .paint_worklet => .paint_worklet,
            .animation_worklet => .animation_worklet,
            .layout_worklet => .layout_worklet,
            .shadow_realm => .shadow_realm,
            .shared_storage_worklet => .shared_storage_worklet,
        };
    }
};

/// V8 Context representing a single page navigation
pub const Context = struct {
    allocator: std.mem.Allocator,
    /// V8 isolate (owned by Browser, not Context)
    isolate: *v8.ffi.Isolate,
    /// V8 context for this navigation
    v8_context: ?*v8.ffi.Context,
    /// Storage subsystem (shared across navigations)
    storage: *Storage,
    /// Current URL
    url: []const u8,
    /// Context type
    context_type: ContextType,
    /// Whether context is ready for execution
    initialized: bool,
    /// Event loop reference (owned by Browser)
    event_loop: ?*v8.V8EventLoop,
    /// Whether to skip interface binding registration (when using snapshot)
    skip_bindings: bool,
    /// Network manager for async fetch (owned by Browser)
    network_manager: ?*anyopaque,

    // Singleton instances for cleanup
    window_instance: ?*runtime.Instance = null,
    document_instance: ?*runtime.Instance = null,
    navigator_instance: ?*runtime.Instance = null,
    location_instance: ?*runtime.Instance = null,
    history_instance: ?*runtime.Instance = null,
    performance_instance: ?*runtime.Instance = null,

    /// Initialize a new Context
    ///
    /// Creates a V8 context within the existing isolate and registers all
    /// browser globals.
    ///
    /// If `skip_bindings` is true (when isolate was created from snapshot),
    /// the interface registration step is skipped since interfaces are already
    /// available in the snapshot.
    pub fn init(
        allocator: std.mem.Allocator,
        isolate: *v8.ffi.Isolate,
        storage: *Storage,
        url: []const u8,
        event_loop: ?*v8.V8EventLoop,
        context_type: ContextType,
        skip_bindings: bool,
        network_manager: ?*anyopaque,
    ) !*Context {
        const ctx = try allocator.create(Context);
        errdefer allocator.destroy(ctx);

        const url_copy = try allocator.dupe(u8, url);
        errdefer allocator.free(url_copy);

        ctx.* = Context{
            .allocator = allocator,
            .isolate = isolate,
            .v8_context = null,
            .storage = storage,
            .url = url_copy,
            .context_type = context_type,
            .initialized = false,
            .event_loop = event_loop,
            .skip_bindings = skip_bindings,
            .network_manager = network_manager,
        };

        try ctx.createV8Context();
        return ctx;
    }

    /// Create V8 context and register globals
    /// Uses a global template with internal fields to support Window instance binding.
    ///
    /// OPTIMIZATION: When skip_bindings is true (isolate was created from snapshot),
    /// we use v8_Context_NewFromSnapshot() which restores a context with all 1,099
    /// WebIDL interfaces already registered. This is the FAST path (~2ms).
    ///
    /// When skip_bindings is false, we create a fresh context and register all
    /// interfaces manually. This is the SLOW path (~40ms).
    fn createV8Context(self: *Context) !void {
        var v8_ctx: *v8.ffi.Context = undefined;

        if (self.skip_bindings) {
            // FAST PATH: Use snapshot context with interfaces already registered
            // The snapshot contains all WebIDL interfaces pre-registered on the global,
            // so we don't need to call initializeBindings() - saving ~1099 registrations.
            // Select the correct snapshot context index based on context type.
            const snapshot_index = self.context_type.toSnapshotIndex();
            v8_ctx = v8.snapshot_loader.createContextFromSnapshotAt(self.isolate, snapshot_index) orelse {
                // Fallback to slow path if snapshot context fails
                std.debug.print("Warning: Snapshot context at index {} failed, falling back to fresh context\n", .{@intFromEnum(snapshot_index)});
                return self.createV8ContextFresh();
            };
        } else {
            // SLOW PATH: Create fresh context without snapshot
            return self.createV8ContextFresh();
        }

        self.v8_context = v8_ctx;
        v8.ffi.v8_Context_Enter(v8_ctx);

        // Initialize context manager for V8 callbacks (only if not already initialized)
        // The context manager is per-thread, so it only needs to be initialized once.
        // Subsequent context creations within the same thread will get AlreadyInitialized.
        context_manager.init(self.allocator) catch |err| {
            if (err != error.AlreadyInitialized) {
                std.debug.print("Warning: Context manager init failed: {}\n", .{err});
            }
        };

        // Initialize callback registry for tracking CallbackWrapper instances
        // This allows proper cleanup of event listeners, promise handlers, etc.
        callback_registry.init(self.allocator);

        // Register context with context manager for wrapper caching
        // Pass timer and event loop interfaces so all runtime contexts share the same libuv loop
        const timer_iface = if (self.event_loop) |ev| ev.timerInterface() else null;
        const event_loop_iface = if (self.event_loop) |ev| ev.eventLoop() else null;
        const runtime_ctx = context_manager.getOrCreateWithExternalEventLoop(v8_ctx, timer_iface, event_loop_iface, self.allocator) catch |err| {
            std.debug.print("Warning: Context registration failed: {}\n", .{err});
            return error.ContextRegistrationFailed;
        };

        // Set network manager on runtime context for async fetch()
        if (self.network_manager) |nm| {
            runtime_ctx.setNetworkManager(nm);
        }

        // SNAPSHOT MODE: The snapshot contains V8 builtins AND WebIDL interfaces.
        // Interfaces are pre-registered in the snapshot with proper external references.
        // We only need to populate the Zig-side template registry so that
        // wrapInstanceAsV8Object() can wrap Document, Navigator, etc. with correct prototypes.
        v8.interface_bindings.registerAllTemplatesOnly(self.isolate);

        // Register namespaces (console, WebAssembly, etc.) which are NOT included in the snapshot.
        v8.interface_bindings.registerNamespacesGeneric(namespaces, self.isolate, v8_ctx);

        // Get the global object
        const global = v8.ffi.v8_Context_Global(v8_ctx) orelse {
            return error.NoGlobal;
        };

        // Set up prototype chain based on context type
        if (self.context_type == .window) {
            // Set up Window prototype chain
            const window_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "Window", 6);
            if (window_key) |wk| {
                if (v8.ffi.v8_Object_Get(global, v8_ctx, @ptrCast(wk))) |window_ctor| {
                    const proto_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "prototype", 9);
                    if (proto_key) |pk| {
                        if (v8.ffi.v8_Object_Get(@ptrCast(window_ctor), v8_ctx, @ptrCast(pk))) |window_proto| {
                            _ = v8.ffi.v8_Object_SetPrototypeV2(global, v8_ctx, window_proto);
                        }
                    }
                }
            }
        } else if (self.context_type == .worker) {
            // Set up DedicatedWorkerGlobalScope prototype chain
            std.debug.print("Context: Setting up Worker prototype chain...\n", .{});
            const worker_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "DedicatedWorkerGlobalScope", 26);
            if (worker_key) |wk| {
                if (v8.ffi.v8_Object_Get(global, v8_ctx, @ptrCast(wk))) |worker_ctor| {
                    std.debug.print("Context: Found DedicatedWorkerGlobalScope constructor\n", .{});
                    const proto_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "prototype", 9);
                    if (proto_key) |pk| {
                        if (v8.ffi.v8_Object_Get(@ptrCast(worker_ctor), v8_ctx, @ptrCast(pk))) |worker_proto| {
                            _ = v8.ffi.v8_Object_SetPrototypeV2(global, v8_ctx, worker_proto);
                            std.debug.print("Context: Worker prototype set successfully\n", .{});
                        }
                    }
                } else {
                    std.debug.print("Context: DedicatedWorkerGlobalScope constructor NOT found on global\n", .{});
                }
            }

            // Create and bind DedicatedWorkerGlobalScope instance
            const DedicatedWorkerGlobalScope = interfaces.DedicatedWorkerGlobalScope;
            const worker_instance = DedicatedWorkerGlobalScope.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create worker instance: {}\n", .{err});
                // Continue without instance binding (will cause crashes if methods called)
                // We can't easily return error here as we are in a block that doesn't propagate easily?
                // Actually createV8Context returns !void, so we can return error.
                return error.ContextCreateFailed;
            };

            // Store instance in internal field 0
            v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 0, @ptrCast(worker_instance));

            // Store WrapperTypeInfo in internal field 1
            if (v8.dom_type_info.getTypeInfoByName("DedicatedWorkerGlobalScope")) |type_info| {
                v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 1, @ptrCast(@constCast(type_info)));
            }

            // Register in wrapper cache (needed for event dispatch to find the V8 object)
            if (runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
                const cache: *v8.wrapper_cache_mod.WrapperCache = @ptrCast(@alignCast(cache_storage));
                cache.set(worker_instance, global, self.isolate) catch {};
            }

            // Check MessageEvent registration
            if (v8.template_registry.getTemplate("MessageEvent") == null) {
                std.debug.print("Context: WARNING - MessageEvent template NOT registered!\n", .{});
            } else {
                std.debug.print("Context: MessageEvent template IS registered\n", .{});
            }
        } else if (self.context_type == .shared_worker) {
            // Set up SharedWorkerGlobalScope prototype chain
            std.debug.print("Context: Setting up SharedWorker prototype chain...\n", .{});
            const worker_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "SharedWorkerGlobalScope", 23);
            if (worker_key) |wk| {
                if (v8.ffi.v8_Object_Get(global, v8_ctx, @ptrCast(wk))) |worker_ctor| {
                    std.debug.print("Context: Found SharedWorkerGlobalScope constructor\n", .{});
                    const proto_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "prototype", 9);
                    if (proto_key) |pk| {
                        if (v8.ffi.v8_Object_Get(@ptrCast(worker_ctor), v8_ctx, @ptrCast(pk))) |worker_proto| {
                            _ = v8.ffi.v8_Object_SetPrototypeV2(global, v8_ctx, worker_proto);
                            std.debug.print("Context: SharedWorker prototype set successfully\n", .{});
                        }
                    }
                } else {
                    std.debug.print("Context: SharedWorkerGlobalScope constructor NOT found on global\n", .{});
                }
            }

            // Create and bind SharedWorkerGlobalScope instance
            const SharedWorkerGlobalScope = interfaces.SharedWorkerGlobalScope;
            const worker_instance = SharedWorkerGlobalScope.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create shared worker instance: {}\n", .{err});
                return error.ContextCreateFailed;
            };

            // Store instance in internal field 0
            v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 0, @ptrCast(worker_instance));

            // Store WrapperTypeInfo in internal field 1
            if (v8.dom_type_info.getTypeInfoByName("SharedWorkerGlobalScope")) |type_info| {
                v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 1, @ptrCast(@constCast(type_info)));
            }

            // Register in wrapper cache (needed for event dispatch to find the V8 object)
            if (runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
                const cache: *v8.wrapper_cache_mod.WrapperCache = @ptrCast(@alignCast(cache_storage));
                cache.set(worker_instance, global, self.isolate) catch {};
            }
        } else if (self.context_type == .service_worker) {
            // Set up ServiceWorkerGlobalScope prototype chain
            std.debug.print("Context: Setting up ServiceWorker prototype chain...\n", .{});
            const worker_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "ServiceWorkerGlobalScope", 24);
            if (worker_key) |wk| {
                if (v8.ffi.v8_Object_Get(global, v8_ctx, @ptrCast(wk))) |worker_ctor| {
                    std.debug.print("Context: Found ServiceWorkerGlobalScope constructor\n", .{});
                    const proto_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "prototype", 9);
                    if (proto_key) |pk| {
                        if (v8.ffi.v8_Object_Get(@ptrCast(worker_ctor), v8_ctx, @ptrCast(pk))) |worker_proto| {
                            _ = v8.ffi.v8_Object_SetPrototypeV2(global, v8_ctx, worker_proto);
                            std.debug.print("Context: ServiceWorker prototype set successfully\n", .{});
                        }
                    }
                } else {
                    std.debug.print("Context: ServiceWorkerGlobalScope constructor NOT found on global\n", .{});
                }
            }

            // Create and bind ServiceWorkerGlobalScope instance
            const ServiceWorkerGlobalScope = interfaces.ServiceWorkerGlobalScope;
            const worker_instance = ServiceWorkerGlobalScope.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create service worker instance: {}\n", .{err});
                return error.ContextCreateFailed;
            };

            // Store instance in internal field 0
            v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 0, @ptrCast(worker_instance));

            // Store WrapperTypeInfo in internal field 1
            if (v8.dom_type_info.getTypeInfoByName("ServiceWorkerGlobalScope")) |type_info| {
                v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 1, @ptrCast(@constCast(type_info)));
            }

            // Register in wrapper cache (needed for event dispatch to find the V8 object)
            if (runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
                const cache: *v8.wrapper_cache_mod.WrapperCache = @ptrCast(@alignCast(cache_storage));
                cache.set(worker_instance, global, self.isolate) catch {};
            }
        }

        // For window contexts only: Create and bind Window instance to global object's internal fields
        // This is required for WebIDL method callbacks to extract the Zig instance from `this`
        if (self.context_type == .window) {
            const Window = interfaces.Window;
            const window_instance = Window.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create Window instance: {}\n", .{err});
                self.window_instance = null;
                return;
            };
            self.window_instance = window_instance;

            // Store Window instance in internal field 0
            v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 0, @ptrCast(window_instance));

            // Store WrapperTypeInfo in internal field 1 for type-safe unwrapping
            if (v8.dom_type_info.getTypeInfoByName("Window")) |type_info| {
                v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 1, @ptrCast(@constCast(type_info)));
            }

            // Bind the V8 global to the Window instance for cross-realm access
            impls.Window.setBoundV8Global(window_instance, @ptrCast(global));

            // Set isSecureContext based on URL scheme
            // Per HTML spec, secure contexts include https, wss, file, and localhost
            const is_secure = self.determineSecureContext();
            impls.Window.setIsSecureContext(window_instance, is_secure);

            // Register Window in wrapper cache for proper cleanup
            if (runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
                const cache: *v8.wrapper_cache_mod.WrapperCache = @ptrCast(@alignCast(cache_storage));
                cache.set(window_instance, global, self.isolate) catch {};
            }

            // CRITICAL: Register Window with context manager so getWindowForContext() works.
            // This is required for iframe browsing context creation in handleIframeInsertion().
            context_manager.setWindowForContext(v8_ctx, window_instance) catch |err| {
                std.debug.print("Warning: Failed to register Window with context manager: {}\n", .{err});
            };

            // Register Window properties (document, navigator, etc.) as own properties on the global object.
            // This is required because the global's prototype is immutable (set via SetImmutableProto),
            // so we can't inherit properties from Window.prototype through the prototype chain.
            // This matches how child contexts (iframes) register Window properties.
            v8.interface_bindings.Window.registerPropertiesAsOwnOnObject(self.isolate, v8_ctx, global);

            // Register methods as own properties on the global object.
            // This includes Window's own methods AND inherited EventTarget methods
            // (addEventListener, removeEventListener, dispatchEvent).
            // The global's immutable prototype means we can't rely on prototype chain lookup,
            // so we must register these methods directly on the global object.
            v8.interface_bindings.Window.registerMethodsAsOwnOnObject(self.isolate, v8_ctx, global);
            v8.interface_bindings.EventTarget.registerMethodsAsOwnOnObject(self.isolate, v8_ctx, global);

            // Set up window property (Window-specific)
            const window_prop_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "window", 6) orelse return error.StringCreationFailed;
            _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(window_prop_key), @ptrCast(global));
        }

        // Set up self and globalThis properties on the global object (shared across all contexts)
        // Per HTML spec, browsers expose these properties:
        // - 'window' references the global Window object (same as globalThis in browsers)
        // - 'self' references the global object (works in both window and worker contexts)
        // - 'globalThis' is the standard reference to the global object
        const window_prop_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "window", 6) orelse return error.StringCreationFailed;
        _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(window_prop_key), @ptrCast(global));

        const self_prop_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "self", 4) orelse return error.StringCreationFailed;
        _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(self_prop_key), @ptrCast(global));

        const global_this_prop_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "globalThis", 10) orelse return error.StringCreationFailed;
        _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(global_this_prop_key), @ptrCast(global));

        // Set up global aliases FIRST (creates __internal object and accessor properties)
        // This must happen before registerBrowserGlobals() which stores singletons in __internal
        self.setupGlobalAliases() catch |err| {
            // Log but continue - setupGlobalAliases failing shouldn't prevent context creation
            std.debug.print("Warning: setupGlobalAliases failed: {} - continuing\n", .{err});
        };

        // Register browser globals based on context type
        // For window context, stores Document, Navigator, etc. in __internal
        try self.registerBrowserGlobals();

        // Set up timer interface in thread-local storage
        // This needs to be available for JavaScript setTimeout/setInterval calls
        if (self.event_loop) |event_loop| {
            if (event_loop.timerInterface()) |timer| {
                setTimerInterface(timer, self.allocator);
            }
        }

        // Set up child context globals callback so iframes get setTimeout/setInterval
        // This callback is invoked by context_manager.createChildContext() when
        // creating V8 contexts for iframes.
        context_manager.setChildContextGlobalsCallback(registerTimerGlobalsOnContext);

        self.initialized = true;
    }

    /// SLOW PATH: Create fresh V8 context without using snapshot
    /// This is used when no snapshot is available, or as a fallback when snapshot context fails.
    fn createV8ContextFresh(self: *Context) !void {
        // Create fresh template with internal fields
        // This allows WebIDL method callbacks to get the Zig instance from `this`
        const global_template = v8.ffi.v8_ObjectTemplate_New(self.isolate);
        v8.ffi.v8_ObjectTemplate_SetInternalFieldCount(global_template, 2);

        // Per WebIDL spec §3.8, all objects in the global prototype chain must have
        // immutable [[Prototype]]. Object.setPrototypeOf(globalThis, {}) must throw TypeError.
        v8.ffi.v8_ObjectTemplate_SetImmutableProto(global_template);

        // Create V8 context with the global template
        const v8_ctx = v8.ffi.v8_Context_NewWithGlobalTemplate(self.isolate, global_template) orelse {
            return error.ContextCreateFailed;
        };
        self.v8_context = v8_ctx;

        v8.ffi.v8_Context_Enter(v8_ctx);

        // Initialize context manager for V8 callbacks (only if not already initialized)
        context_manager.init(self.allocator) catch |err| {
            if (err != error.AlreadyInitialized) {
                std.debug.print("Warning: Context manager init failed: {}\n", .{err});
            }
        };

        // Initialize callback registry for tracking CallbackWrapper instances
        // This allows proper cleanup of event listeners, promise handlers, etc.
        callback_registry.init(self.allocator);

        // Register context with context manager for wrapper caching
        const timer_iface = if (self.event_loop) |ev| ev.timerInterface() else null;
        const event_loop_iface = if (self.event_loop) |ev| ev.eventLoop() else null;
        const runtime_ctx = context_manager.getOrCreateWithExternalEventLoop(v8_ctx, timer_iface, event_loop_iface, self.allocator) catch |err| {
            std.debug.print("Warning: Context registration failed: {}\n", .{err});
            return error.ContextRegistrationFailed;
        };

        // Set network manager on runtime context for async fetch()
        if (self.network_manager) |nm| {
            runtime_ctx.setNetworkManager(nm);
        }

        // SLOW PATH: Register all WebIDL interfaces manually
        // This is required for fresh contexts without snapshot
        v8.interface_bindings.initializeBindingsWithGlobalTemplate(self.isolate, v8_ctx);

        // Register all namespaces
        v8.interface_bindings.registerNamespacesGeneric(namespaces, self.isolate, v8_ctx);

        // Get the global object
        const global = v8.ffi.v8_Context_Global(v8_ctx) orelse {
            return error.NoGlobal;
        };

        // Set up prototype chain based on context type
        if (self.context_type == .window) {
            // Set up Window prototype chain
            const window_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "Window", 6);
            if (window_key) |wk| {
                if (v8.ffi.v8_Object_Get(global, v8_ctx, @ptrCast(wk))) |window_ctor| {
                    const proto_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "prototype", 9);
                    if (proto_key) |pk| {
                        if (v8.ffi.v8_Object_Get(@ptrCast(window_ctor), v8_ctx, @ptrCast(pk))) |window_proto| {
                            _ = v8.ffi.v8_Object_SetPrototypeV2(global, v8_ctx, window_proto);
                        }
                    }
                }
            }
        } else if (self.context_type == .worker) {
            // Set up DedicatedWorkerGlobalScope prototype chain
            // Note: This logic mirrors createV8Context (fast path) to ensure workers using fresh isolates
            // also get the correct prototype chain.
            const worker_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "DedicatedWorkerGlobalScope", 26);
            if (worker_key) |wk| {
                if (v8.ffi.v8_Object_Get(global, v8_ctx, @ptrCast(wk))) |worker_ctor| {
                    const proto_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "prototype", 9);
                    if (proto_key) |pk| {
                        if (v8.ffi.v8_Object_Get(@ptrCast(worker_ctor), v8_ctx, @ptrCast(pk))) |worker_proto| {
                            _ = v8.ffi.v8_Object_SetPrototypeV2(global, v8_ctx, worker_proto);
                        }
                    }
                }
            }

            // Create and bind DedicatedWorkerGlobalScope instance
            const DedicatedWorkerGlobalScope = interfaces.DedicatedWorkerGlobalScope;
            const worker_instance = DedicatedWorkerGlobalScope.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create worker instance: {}\n", .{err});
                return error.ContextCreateFailed;
            };

            // Store instance in internal field 0
            v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 0, @ptrCast(worker_instance));

            // Store WrapperTypeInfo in internal field 1
            if (v8.dom_type_info.getTypeInfoByName("DedicatedWorkerGlobalScope")) |type_info| {
                v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 1, @ptrCast(@constCast(type_info)));
            }

            // Register in wrapper cache
            if (runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
                const cache: *v8.wrapper_cache_mod.WrapperCache = @ptrCast(@alignCast(cache_storage));
                cache.set(worker_instance, global, self.isolate) catch {};
            }
        }

        // Create and bind Window instance
        const Window = interfaces.Window;
        const window_instance = Window.init(self.allocator, runtime_ctx) catch |err| {
            std.debug.print("Warning: Failed to create Window instance: {}\n", .{err});
            self.window_instance = null;
            return;
        };
        self.window_instance = window_instance;

        // Store Window instance in internal field 0
        v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 0, @ptrCast(window_instance));

        // Store WrapperTypeInfo in internal field 1
        if (v8.dom_type_info.getTypeInfoByName("Window")) |type_info| {
            v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 1, @ptrCast(@constCast(type_info)));
        }

        // Bind the V8 global to the Window instance
        impls.Window.setBoundV8Global(window_instance, @ptrCast(global));

        // Set isSecureContext based on URL scheme
        // Per HTML spec, secure contexts include https, wss, file, and localhost
        const is_secure = self.determineSecureContext();
        impls.Window.setIsSecureContext(window_instance, is_secure);

        // Register Window in wrapper cache
        if (runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
            const cache: *v8.wrapper_cache_mod.WrapperCache = @ptrCast(@alignCast(cache_storage));
            cache.set(window_instance, global, self.isolate) catch {};
        }

        // CRITICAL: Register Window with context manager so getWindowForContext() works.
        // This is required for iframe browsing context creation in handleIframeInsertion().
        context_manager.setWindowForContext(v8_ctx, window_instance) catch |err| {
            std.debug.print("Warning: Failed to register Window with context manager: {}\n", .{err});
        };

        // Register Window properties as own properties on the global object
        v8.interface_bindings.Window.registerPropertiesAsOwnOnObject(self.isolate, v8_ctx, global);

        // Set up global aliases
        self.setupGlobalAliases() catch |err| {
            std.debug.print("Warning: setupGlobalAliases failed: {} - continuing\n", .{err});
        };

        // Register browser globals
        try self.registerBrowserGlobals();

        // Set up timer interface
        if (self.event_loop) |event_loop| {
            if (event_loop.timerInterface()) |timer| {
                setTimerInterface(timer, self.allocator);
            }
        }

        // Set up child context globals callback so iframes get setTimeout/setInterval
        context_manager.setChildContextGlobalsCallback(registerTimerGlobalsOnContext);

        self.initialized = true;
    }

    /// Register browser globals based on context type
    fn registerBrowserGlobals(self: *Context) !void {
        const v8_ctx = self.v8_context orelse return error.NotInitialized;
        const global_obj = v8.ffi.v8_Context_Global(v8_ctx) orelse return error.NoGlobal;

        // Get runtime context for wrapper caching
        const runtime_ctx = context_manager.getOrCreate(v8_ctx, self.allocator) catch |err| {
            std.debug.print("Warning: Failed to get runtime context: {}\n", .{err});
            return;
        };

        switch (self.context_type) {
            .window => try self.registerWindowGlobals(global_obj, runtime_ctx),
            .worker => try self.registerWorkerGlobals(global_obj, runtime_ctx),
            else => {},
        }

        // Register common globals (setTimeout, fetch, console, etc.)
        try self.registerCommonGlobals(global_obj);
    }

    /// Register Window context globals
    /// NOTE: Singletons are stored in __internal object, accessed via accessor properties
    /// defined in setupGlobalAliases(). This follows the WebIDL spec pattern.
    fn registerWindowGlobals(
        self: *Context,
        global_obj: *v8.ffi.Object,
        runtime_ctx: runtime.Context,
    ) !void {
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        // NOTE: 'self' is handled by Window interface accessor property (get_self).
        // Do NOT set 'self' as a data property here - it would overwrite the accessor
        // and result in the raw Global<Object>* pointer being visible to JavaScript
        // as a number instead of the actual global object.

        // Get __internal object for storing singleton values
        // The accessor properties defined in setupGlobalAliases() read from __internal
        const internal_key = v8.ffi.v8_String_NewFromUtf8(isolate, "__internal", 10) orelse return error.StringCreateFailed;
        const internal_obj = v8.ffi.v8_Object_Get(global_obj, v8_ctx, @ptrCast(internal_key)) orelse {
            std.debug.print("Warning: __internal object not found on global\n", .{});
            return error.ObjectNotFound;
        };

        // Register Document singleton (stored in __internal.document)
        {
            const Document = interfaces.Document;
            const doc_instance = Document.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create document singleton: {}\n", .{err});
                return;
            };
            self.document_instance = doc_instance;

            // Link the document to the Window instance so window.document accessor works
            // Also link the Window to the Document so document.location and document.defaultView work
            if (self.window_instance) |win| {
                impls.Window.setDocument(win, doc_instance);
                impls.Document.setDefaultView(doc_instance, win);
            }

            const v8_document = v8.template_registry.wrapInstanceAsV8Object(
                doc_instance,
                "Document",
                isolate,
                v8_ctx,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap document: {}\n", .{err});
                return;
            };

            const doc_key = v8.ffi.v8_String_NewFromUtf8(isolate, "document", 8) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(@ptrCast(internal_obj), v8_ctx, @ptrCast(doc_key), @ptrCast(v8_document));
        }

        // Register Navigator singleton (stored in __internal.navigator)
        {
            const Navigator = interfaces.Navigator;
            const nav_instance = Navigator.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create navigator: {}\n", .{err});
                return;
            };
            self.navigator_instance = nav_instance;

            // Link the navigator to the Window instance so window.navigator accessor works
            if (self.window_instance) |win| {
                impls.Window.setNavigator(win, nav_instance);
            }

            const v8_navigator = v8.template_registry.wrapInstanceAsV8Object(
                nav_instance,
                "Navigator",
                isolate,
                v8_ctx,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap navigator: {}\n", .{err});
                // Clean up the instance we just created to avoid memory leak
                Navigator.deinit(nav_instance);
                self.navigator_instance = null;
                return;
            };

            const nav_key = v8.ffi.v8_String_NewFromUtf8(isolate, "navigator", 9) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(@ptrCast(internal_obj), v8_ctx, @ptrCast(nav_key), @ptrCast(v8_navigator));
        }

        // Register Location singleton (stored in __internal.location)
        {
            const Location = interfaces.Location;
            const loc_instance = Location.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create location: {}\n", .{err});
                return;
            };
            self.location_instance = loc_instance;

            // Link the location to the Window instance so window.location accessor works
            if (self.window_instance) |win| {
                impls.Window.setLocation(win, loc_instance);
            }

            const v8_location = v8.template_registry.wrapInstanceAsV8Object(
                loc_instance,
                "Location",
                isolate,
                v8_ctx,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap location: {}\n", .{err});
                // Clean up the instance we just created to avoid memory leak
                Location.deinit(loc_instance);
                self.location_instance = null;
                return;
            };

            const loc_key = v8.ffi.v8_String_NewFromUtf8(isolate, "location", 8) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(@ptrCast(internal_obj), v8_ctx, @ptrCast(loc_key), @ptrCast(v8_location));
        }

        // Register History singleton (stored in __internal.history)
        {
            const History = interfaces.History;
            const hist_instance = History.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create history: {}\n", .{err});
                return;
            };
            self.history_instance = hist_instance;

            // Link the history to the Window instance so window.history accessor works
            if (self.window_instance) |win| {
                impls.Window.setHistory(win, hist_instance);
            }

            const v8_history = v8.template_registry.wrapInstanceAsV8Object(
                hist_instance,
                "History",
                isolate,
                v8_ctx,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap history: {}\n", .{err});
                // Clean up the instance we just created to avoid memory leak
                History.deinit(hist_instance);
                self.history_instance = null;
                return;
            };

            const hist_key = v8.ffi.v8_String_NewFromUtf8(isolate, "history", 7) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(@ptrCast(internal_obj), v8_ctx, @ptrCast(hist_key), @ptrCast(v8_history));
        }

        // Register Performance singleton (stored in __internal.performance)
        {
            const Performance = interfaces.Performance;
            const perf_instance = Performance.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create performance: {}\n", .{err});
                return;
            };
            self.performance_instance = perf_instance;

            // Link the performance to the Window instance so window.performance accessor works
            if (self.window_instance) |win| {
                impls.Window.setPerformance(win, perf_instance);
            }

            const v8_performance = v8.template_registry.wrapInstanceAsV8Object(
                perf_instance,
                "Performance",
                isolate,
                v8_ctx,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap performance: {}\n", .{err});
                // Clean up the instance we just created to avoid memory leak
                Performance.deinit(perf_instance);
                self.performance_instance = null;
                return;
            };

            const perf_key = v8.ffi.v8_String_NewFromUtf8(isolate, "performance", 11) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(@ptrCast(internal_obj), v8_ctx, @ptrCast(perf_key), @ptrCast(v8_performance));
        }

        // Register HTMLDocument as legacy alias for Document
        // Per HTML spec, HTMLDocument is a historical alias that maps to Document
        {
            const doc_key = v8.ffi.v8_String_NewFromUtf8(isolate, "Document", 8) orelse return error.StringCreateFailed;
            const doc_ctor = v8.ffi.v8_Object_Get(global_obj, v8_ctx, @ptrCast(doc_key));
            if (doc_ctor) |ctor| {
                const html_doc_key = v8.ffi.v8_String_NewFromUtf8(isolate, "HTMLDocument", 12) orelse return error.StringCreateFailed;
                _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(html_doc_key), ctor);
            }
        }
    }

    /// Register Worker context globals
    fn registerWorkerGlobals(
        self: *Context,
        global_obj: *v8.ffi.Object,
        runtime_ctx: runtime.Context,
    ) !void {
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        // Register 'self' as reference to global object
        const self_key = v8.ffi.v8_String_NewFromUtf8(isolate, "self", 4) orelse return error.StringCreateFailed;
        _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(self_key), @ptrCast(global_obj));

        // Register WorkerNavigator
        {
            const WorkerNavigator = interfaces.WorkerNavigator;
            const nav_instance = WorkerNavigator.init(self.allocator, runtime_ctx) catch |err| {
                std.debug.print("Warning: Failed to create worker navigator: {}\n", .{err});
                return;
            };

            const v8_navigator = v8.template_registry.wrapInstanceAsV8Object(
                nav_instance,
                "WorkerNavigator",
                isolate,
                v8_ctx,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap worker navigator: {}\n", .{err});
                return;
            };

            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "navigator", 9) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(v8_navigator));
        }
    }

    /// Register common globals (setTimeout, fetch, console, etc.)
    fn registerCommonGlobals(self: *Context, global_obj: *v8.ffi.Object) !void {
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        // setTimeout
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, setTimeoutCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "setTimeout", 10) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // clearTimeout
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, clearTimeoutCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "clearTimeout", 12) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // setInterval
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, setIntervalCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "setInterval", 11) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // clearInterval
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, clearTimeoutCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "clearInterval", 13) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // NOTE: addEventListener, removeEventListener, and dispatchEvent are now provided
        // by the WebIDL EventTarget interface (registered via initializeBindingsWithGlobalTemplate).
        // Previously, NOOP stubs were registered here that overwrote the proper bindings,
        // breaking all event handling. The EventTarget implementation in src/webidl/impls/EventTarget.zig
        // provides the actual functionality.

        // NOTE: console is now registered via registerNamespacesGeneric() in createV8Context()
        // before this function is called. The namespace system provides the actual console
        // implementation with Zig callbacks. The old JavaScript noop console has been removed.
        //
        // Previously, this code created a JavaScript-based noop console that OVERWROTE the
        // properly registered console namespace, breaking console.log callbacks.

        // Register btoa/atob for base64 encoding/decoding
        {
            const btoa_atob_script =
                \\(function() {
                \\  // btoa: binary string to base64
                \\  globalThis.btoa = function(str) {
                \\    var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
                \\    var result = '';
                \\    var i = 0;
                \\    while (i < str.length) {
                \\      var a = str.charCodeAt(i++) || 0;
                \\      var b = str.charCodeAt(i++) || 0;
                \\      var c = str.charCodeAt(i++) || 0;
                \\      var triplet = (a << 16) | (b << 8) | c;
                \\      result += chars[(triplet >> 18) & 63];
                \\      result += chars[(triplet >> 12) & 63];
                \\      result += (i > str.length + 1) ? '=' : chars[(triplet >> 6) & 63];
                \\      result += (i > str.length) ? '=' : chars[triplet & 63];
                \\    }
                \\    return result;
                \\  };
                \\  
                \\  // atob: base64 to binary string
                \\  globalThis.atob = function(str) {
                \\    var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
                \\    str = str.replace(/=+$/, '');
                \\    var result = '';
                \\    var i = 0;
                \\    while (i < str.length) {
                \\      var a = chars.indexOf(str[i++]);
                \\      var b = chars.indexOf(str[i++]);
                \\      var c = chars.indexOf(str[i++]);
                \\      var d = chars.indexOf(str[i++]);
                \\      var triplet = (a << 18) | (b << 12) | (c << 6) | d;
                \\      result += String.fromCharCode((triplet >> 16) & 255);
                \\      if (c !== -1) result += String.fromCharCode((triplet >> 8) & 255);
                \\      if (d !== -1) result += String.fromCharCode(triplet & 255);
                \\    }
                \\    return result;
                \\  };
                \\})();
            ;
            _ = self.evaluateScript(btoa_atob_script) catch |err| {
                std.debug.print("Warning: Failed to register btoa/atob: {}\n", .{err});
            };
        }

        // NOTE: getComputedStyle and fetch are registered via Window.registerMethodsAsOwnOnObject()
        // which properly delegates to the WebIDL implementations. Do NOT register stubs here.
    }

    /// Set up global aliases via JavaScript
    /// Per WebIDL spec, window properties use accessor properties with proper this validation
    fn setupGlobalAliases(self: *Context) !void {
        const setup_script = switch (self.context_type) {
            .window =>
            // Window context: Set up __internal for singleton storage and GLOBAL for WPT tests
            // NOTE: Do NOT set self or window here! They are accessor properties registered by
            // registerPropertiesAsOwnOnObject() via the Window interface. Setting them here
            // would overwrite the accessor with a data property, breaking the getter mechanism.
            // NOTE: Do NOT try to set parent, top, opener, frames, length here!
            // These are read-only accessor properties defined by Window interface bindings.
            // The Window impl handles returning the correct values for these properties.
            \\globalThis.__internal = globalThis.__internal || { isSecureContext: false };
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return true; },
            \\  isWorker: function() { return false; },
            \\  isShadowRealm: function() { return false; }
            \\};
            \\
            \\// NOTE: document, navigator, location, history, performance are exposed via
            \\// the Window interface's attribute getters. We only set up __internal for
            \\// storage, and the Window impl's getters retrieve from there.
            ,
            .worker =>
            // Dedicated worker context: self, navigator, location
            \\function __checkGlobalThis(thisArg, propName) {
            \\  if (thisArg === null || thisArg === undefined) {
            \\    return globalThis;
            \\  }
            \\  if (thisArg === globalThis) {
            \\    return globalThis;
            \\  }
            \\  throw new TypeError("'" + propName + "' called on an object that does not implement interface DedicatedWorkerGlobalScope.");
            \\}
            \\
            \\Object.defineProperty(globalThis, 'self', {
            \\  get: function() { return __checkGlobalThis(this, 'self'); },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Set up GLOBAL object for WPT tests - WORKER context
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
            ,
            .shared_worker, .service_worker =>
            // Shared/Service worker context: only self, no window
            \\function __checkGlobalThis(thisArg, propName) {
            \\  if (thisArg === null || thisArg === undefined) {
            \\    return globalThis;
            \\  }
            \\  if (thisArg === globalThis) {
            \\    return globalThis;
            \\  }
            \\  throw new TypeError("'" + propName + "' called on an object that does not implement interface WorkerGlobalScope.");
            \\}
            \\
            \\Object.defineProperty(globalThis, 'self', {
            \\  get: function() { return __checkGlobalThis(this, 'self'); },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Set up GLOBAL object for WPT tests - WORKER context
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
            ,
            .audio_worklet, .paint_worklet, .animation_worklet, .layout_worklet, .shared_storage_worklet =>
            // Worklet context: minimal global scope per Worklet spec
            // Worklets have a highly restricted execution environment
            \\function __checkGlobalThis(thisArg, propName) {
            \\  if (thisArg === null || thisArg === undefined) {
            \\    return globalThis;
            \\  }
            \\  if (thisArg === globalThis) {
            \\    return globalThis;
            \\  }
            \\  throw new TypeError("'" + propName + "' called on an object that does not implement interface WorkletGlobalScope.");
            \\}
            \\
            \\Object.defineProperty(globalThis, 'self', {
            \\  get: function() { return __checkGlobalThis(this, 'self'); },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Set up GLOBAL object for WPT tests - WORKLET context
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return false; },
            \\  isWorklet: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
            ,
            .shadow_realm =>
            // ShadowRealm context: isolated realm per TC39 Stage 3 proposal
            // ShadowRealms have minimal global scope - no DOM, no I/O
            // Only pure JavaScript built-ins are available
            \\// Set up GLOBAL object for WPT tests - SHADOWREALM context
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return false; },
            \\  isShadowRealm: function() { return true; },
            \\};
            ,
        };

        _ = self.evaluateScript(setup_script) catch |err| {
            std.debug.print("ERROR: Failed to set up global aliases: {}\n", .{err});
            return err;
        };
    }

    /// Load page content (fetch, parse, execute)
    ///
    /// Navigation flow per HTML Standard:
    /// 1. Fetch URL content
    /// 2. Detect response content type
    /// 3. Delegate to appropriate handler (HTML, JSON, plain text, etc.)
    /// 4. Fire DOMContentLoaded and load events
    pub fn loadPage(self: *Context) !void {
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        // Step 1: Fetch URL content
        // For about:blank, return early without fetching (empty document)
        if (std.mem.eql(u8, self.url, "about:blank")) {
            return;
        }

        var result = navigation.fetchUrl(self.allocator, self.url, .{}) catch |err| {
            // Handle navigation errors gracefully
            std.debug.print("Navigation error for {s}: {}\n", .{ self.url, err });
            return error.NavigationFailed;
        };
        defer result.deinit();

        // Step 2: Detect content type and delegate to appropriate handler
        if (isHtmlContentType(result.content_type)) {
            try self.handleHtmlResponse(result.body, v8_ctx);
        } else if (isJsonContentType(result.content_type)) {
            try self.handleJsonResponse(result.body);
        } else if (isTextContentType(result.content_type)) {
            try self.handleTextResponse(result.body);
        } else {
            // Unknown content type - treat as binary/download
            std.debug.print("Unhandled content type: {s}\n", .{result.content_type});
            return;
        }
    }

    /// Check if content type is HTML
    fn isHtmlContentType(content_type: []const u8) bool {
        return std.mem.indexOf(u8, content_type, "text/html") != null or
            std.mem.indexOf(u8, content_type, "application/xhtml") != null;
    }

    /// Check if content type is JSON
    fn isJsonContentType(content_type: []const u8) bool {
        return std.mem.indexOf(u8, content_type, "application/json") != null or
            std.mem.indexOf(u8, content_type, "text/json") != null;
    }

    /// Check if content type is plain text
    fn isTextContentType(content_type: []const u8) bool {
        return std.mem.indexOf(u8, content_type, "text/plain") != null or
            std.mem.indexOf(u8, content_type, "text/css") != null or
            std.mem.indexOf(u8, content_type, "text/javascript") != null or
            std.mem.indexOf(u8, content_type, "application/javascript") != null;
    }

    /// Handle HTML response - parse with full HTML parser including script execution
    fn handleHtmlResponse(self: *Context, html_content: []const u8, v8_ctx: *v8.ffi.Context) !void {
        // Get runtime context for HTMLParser
        const runtime_ctx = context_manager.getOrCreate(v8_ctx, self.allocator) catch |err| {
            std.debug.print("Failed to get runtime context: {}\n", .{err});
            return error.NotInitialized;
        };

        // Get existing document instance
        const document = self.document_instance orelse {
            std.debug.print("ERROR: document_instance is null - context must be initialized first\n", .{});
            return error.NotInitialized;
        };

        // Update document URL to the actual page URL
        if (impls.Document.getInternal(document)) |doc_internal| {
            // Free old URL if it exists
            if (doc_internal.url.len > 0) {
                self.allocator.free(doc_internal.url);
            }
            doc_internal.url = self.allocator.dupe(u8, self.url) catch "";
        }

        // Parse HTML with full scripting support
        const HTMLParser = impls.HTMLParser;
        _ = HTMLParser.parseHTMLWithScripting(
            self.allocator,
            runtime_ctx,
            html_content,
            .{
                .scripting_enabled = true,
                .base_url = self.url,
                .script_loader = null, // Use default HTTP fetching
                .existing_document = document,
            },
        ) catch |err| {
            std.debug.print("HTML parse error: {}\n", .{err});
            return error.ParseError;
        };

        // Fire DOMContentLoaded on document
        if (self.document_instance) |doc| {
            navigation.fireDOMContentLoaded(self.allocator, doc);
        }

        // Fire load event on window
        if (self.window_instance) |win| {
            navigation.fireLoad(self.allocator, win);
        }
    }

    /// Handle JSON response - set document body with formatted JSON
    fn handleJsonResponse(self: *Context, json_content: []const u8) !void {
        // For JSON, we could parse and display, or set as document content
        // For now, just log it - full implementation would create a JSON viewer
        _ = self;
        std.debug.print("JSON response ({d} bytes)\n", .{json_content.len});
    }

    /// Handle plain text response - set document body with text content
    fn handleTextResponse(self: *Context, text_content: []const u8) !void {
        // For text, display in a <pre> element or similar
        _ = self;
        std.debug.print("Text response ({d} bytes)\n", .{text_content.len});
    }

    /// Evaluate script with error handling (doesn't propagate errors)
    fn evaluateScriptSafe(
        self: *Context,
        script: []const u8,
        isolate: *v8.ffi.Isolate,
        v8_ctx: *v8.ffi.Context,
    ) ?*v8.ffi.Value {
        _ = self;

        const source_str = v8.ffi.v8_String_NewFromUtf8(
            isolate,
            script.ptr,
            @intCast(script.len),
        ) orelse return null;

        const compiled = v8.ffi.v8_Script_Compile(v8_ctx, source_str) orelse {
            // Log compile error but continue
            const exception = v8.ffi.v8_TryCatch_Exception(v8_ctx);
            if (exception) |exc| {
                const exc_str = v8.ffi.v8_Value_ToString(exc, v8_ctx);
                if (exc_str) |str| {
                    var buf: [1024]u8 = undefined;
                    const len = v8.ffi.v8_String_Utf8Length(str);
                    const write_len: usize = @min(@as(usize, @intCast(len)), buf.len - 1);
                    _ = v8.ffi.v8_String_WriteUtf8(str, &buf, @intCast(write_len));
                    std.debug.print("Script compile error: {s}\n", .{buf[0..write_len]});
                }
            }
            return null;
        };

        const result = v8.ffi.v8_Script_Run(v8_ctx, compiled);

        // Run microtasks
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

        return result;
    }

    // ============================================================================
    // HTML Loading and Parsing
    // ============================================================================

    /// Script loader callback type for external script loading
    /// Returns script content for the given URL, or null if loading failed
    pub const ScriptLoaderFn = *const fn (ctx: *anyopaque, url: []const u8) ?[]const u8;

    /// Script loader interface for customizing how external scripts are loaded
    pub const ScriptLoader = struct {
        context: *anyopaque,
        loadScript: ScriptLoaderFn,
    };

    /// Options for HTML loading
    pub const LoadHTMLOptions = struct {
        /// Base URL for resolving relative URLs
        base_url: []const u8,
        /// Enable script execution during parsing (default: true)
        scripting_enabled: bool = true,
        /// Custom script loader (optional)
        /// If null, external scripts will use default HTTP fetch
        script_loader: ?ScriptLoader = null,
        /// Certificate trust store for HTTPS script fetching (e.g., WPT self-signed certs)
        trust_store: ?*const @import("fetch").network.CertificateTrustStore = null,
    };

    /// Load and parse HTML content into the document
    ///
    /// This method:
    /// 1. Sets up the document URL and Window origin
    /// 2. Parses HTML using HTMLParser.parseHTMLWithScripting()
    /// 3. Executes inline and external scripts during parsing
    /// 4. Initializes iframe browsing contexts
    /// 5. Fires DOMContentLoaded after parsing
    ///
    /// Per HTML Standard §13.2.7 "The end":
    /// - Scripts execute during parsing (inline and deferred)
    /// - DOMContentLoaded fires after parsing completes
    ///
    /// ## Example
    /// ```zig
    /// const html =
    ///     \\<html>
    ///     \\<body>
    ///     \\<div id="test">Hello</div>
    ///     \\<script>
    ///     \\  window.found = document.getElementById('test').textContent;
    ///     \\</script>
    ///     \\</body>
    ///     \\</html>
    /// ;
    /// try ctx.loadHTML(html, .{ .base_url = "about:blank" });
    /// const result = try ctx.evaluateScript("window.found");
    /// // result === "Hello"
    /// ```
    pub fn loadHTML(self: *Context, html_content: []const u8, options: LoadHTMLOptions) !void {
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        std.debug.print("loadHTML: Browser.Context v8_context={*}\n", .{v8_ctx});

        // Get runtime context for HTMLParser
        const runtime_ctx = context_manager.getOrCreate(v8_ctx, self.allocator) catch |err| {
            std.debug.print("Failed to get runtime context: {}\n", .{err});
            return error.NotInitialized;
        };

        std.debug.print("loadHTML: runtime_ctx engine_ctx={*}\n", .{runtime_ctx.getEngineContext()});

        // Update location object with the document's URL
        try self.setUrl(options.base_url);

        // Set the Window's origin from the base URL for storage access
        // This is needed for sessionStorage/localStorage to work properly
        if (self.window_instance) |win| {
            if (std.mem.startsWith(u8, options.base_url, "http://") or std.mem.startsWith(u8, options.base_url, "https://")) {
                // Extract origin from URL (scheme://host:port)
                const scheme_end = std.mem.indexOf(u8, options.base_url, "://") orelse options.base_url.len;
                const after_scheme = options.base_url[scheme_end + 3 ..];
                const path_start = std.mem.indexOf(u8, after_scheme, "/") orelse after_scheme.len;
                const origin = options.base_url[0 .. scheme_end + 3 + path_start];
                impls.Window.setOrigin(win, origin) catch |err| {
                    std.debug.print("Warning: Failed to set Window origin: {}\n", .{err});
                };
            }
        }

        // Get existing document instance - it was created during context initialization
        // and is already registered in V8. We pass it to the parser so scripts can
        // access the DOM via document.getElementById(), querySelector(), etc.
        const document = self.document_instance orelse {
            std.debug.print("ERROR: document_instance is null - context must be initialized first\n", .{});
            return error.NotInitialized;
        };

        // Create HTMLParser script loader
        const HTMLParser = impls.HTMLParser;
        const script_loader: ?HTMLParser.ScriptLoader = if (options.script_loader) |loader|
            HTMLParser.ScriptLoader{
                .context = loader.context,
                .loadScript = @ptrCast(loader.loadScript),
            }
        else
            null;

        // Parse HTML into the existing document (already registered in V8)
        _ = HTMLParser.parseHTMLWithScripting(
            self.allocator,
            runtime_ctx,
            html_content,
            .{
                .scripting_enabled = options.scripting_enabled,
                .base_url = options.base_url,
                .script_loader = script_loader,
                .existing_document = document,
                .trust_store = options.trust_store,
            },
        ) catch |err| {
            std.debug.print("HTML parse error: {}\n", .{err});
            return error.ParseError;
        };

        // Initialize browsing contexts for any iframes in the document
        // This is necessary for window.frames[N] to work properly
        self.initializeIframeBrowsingContexts(document) catch |err| {
            // Non-fatal - some iframes may not need initialization
            std.debug.print("Warning: Failed to initialize iframe browsing contexts: {}\n", .{err});
        };

        // Fire DOMContentLoaded event
        // Per HTML Standard §13.2.7 "The end" step 4
        navigation.fireDOMContentLoaded(self.allocator, document);

        // Fire load event
        // Per HTML Standard §13.2.7 "The end" step 9
        if (self.window_instance) |win| {
            navigation.fireLoad(self.allocator, win);
        }
    }

    /// Initialize browsing contexts for all iframes in a document.
    /// This triggers lazy initialization of iframe browsing contexts by accessing
    /// their contentWindow property, which is required for window.frames[N] to work.
    fn initializeIframeBrowsingContexts(self: *Context, document: *runtime.Instance) !void {
        _ = self;

        // Get all iframe elements using getElementsByTagName
        const iframes = try interfaces.Document.call_getElementsByTagName(
            document,
            runtime.DOMString.initInterned("iframe"),
        );

        // Get the collection length
        const length = try interfaces.HTMLCollection.get_length(iframes);
        if (length == 0) return;

        // Access contentWindow on each iframe to trigger browsing context initialization
        var i: u32 = 0;
        while (i < length) : (i += 1) {
            const element = try interfaces.HTMLCollection.call_item(iframes, i);
            if (element) |iframe_elem| {
                // Access contentWindow to trigger IFrameIntegration.ensureBrowsingContext
                _ = impls.HTMLIFrameElement.get_contentWindow(iframe_elem) catch |err| {
                    std.debug.print("Warning: Failed to initialize iframe {d}: {}\n", .{ i, err });
                };
            }
        }
    }

    /// Set the context URL (updates location object)
    fn setUrl(self: *Context, url: []const u8) !void {
        // Update internal URL
        self.allocator.free(self.url);
        self.url = try self.allocator.dupe(u8, url);

        // Update Location object with the new URL
        // This is required for location.pathname, location.href, etc. to work correctly
        if (self.location_instance) |loc| {
            const LocationImpl = impls.Location;
            try LocationImpl.setURLFromString(loc, url);
        }
    }

    /// Determine if the current URL represents a secure context
    /// Per HTML spec, secure contexts include:
    /// - https:// and wss:// URLs
    /// - file:// URLs
    /// - localhost and 127.0.0.1 and [::1] regardless of scheme
    fn determineSecureContext(self: *Context) bool {
        // Parse the URL to extract scheme and host
        const url_str = self.url;

        // Find scheme (everything before "://")
        const scheme_end = std.mem.indexOf(u8, url_str, "://") orelse {
            // No scheme found - treat as insecure
            return false;
        };
        const scheme = url_str[0..scheme_end];

        // Check if scheme is inherently secure
        if (impls.Window.isSecureScheme(scheme)) {
            return true;
        }

        // Extract host (after "://" and before "/" or ":" or end)
        const after_scheme = url_str[scheme_end + 3 ..];
        var host_end = after_scheme.len;

        // Find end of host (first "/" or ":" for port)
        if (std.mem.indexOf(u8, after_scheme, "/")) |pos| {
            host_end = @min(host_end, pos);
        }
        if (std.mem.indexOf(u8, after_scheme, ":")) |pos| {
            host_end = @min(host_end, pos);
        }

        const host = after_scheme[0..host_end];

        // Check if localhost (secure regardless of scheme)
        return impls.Window.isSecureLocalhost(host);
    }

    /// Evaluate JavaScript in this context
    pub fn evaluateScript(self: *Context, script: []const u8) !?*v8.ffi.Value {
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        // Debug: v8_ctx and script.len available if needed

        // Create V8 string from content
        const source_str = v8.ffi.v8_String_NewFromUtf8(isolate, script.ptr, @intCast(script.len)) orelse {
            return error.StringCreateFailed;
        };

        // Compile script
        const compiled = v8.ffi.v8_Script_Compile(v8_ctx, source_str) orelse {
            const exception = v8.ffi.v8_TryCatch_Exception(v8_ctx);
            if (exception) |exc| {
                const exc_str = v8.ffi.v8_Value_ToString(exc, v8_ctx);
                if (exc_str) |str| {
                    const len = v8.ffi.v8_String_Utf8Length(str);
                    const buffer = self.allocator.alloc(u8, @intCast(len)) catch return error.CompileError;
                    defer self.allocator.free(buffer);
                    _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
                    std.debug.print("Script compile error: {s}\n", .{buffer});
                }
            }
            return error.CompileError;
        };

        // Run script using safe variant that properly captures exceptions
        const run_result = v8.ffi.v8_Script_Run_Safe(v8_ctx, compiled);
        defer v8.ffi.v8_FreeScriptRunResult(run_result);

        if (run_result.error_info) |err_info| {
            // Print detailed error information
            if (err_info.message) |msg| {
                std.debug.print("Script runtime error: {s}\n", .{msg});
            }
            if (err_info.source_line) |line| {
                std.debug.print("  Source line: {s}\n", .{line});
            }
            if (err_info.resource_name) |name| {
                std.debug.print("  Resource: {s}:{d}:{d}\n", .{ name, err_info.line_number, err_info.column_number });
            }
            if (err_info.stack_trace) |stack| {
                std.debug.print("  Stack trace:\n{s}\n", .{stack});
            }
            return error.RuntimeError;
        }

        // Run microtasks
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

        return run_result.value;
    }

    /// Deinitialize the context
    pub fn deinit(self: *Context) void {
        // Clear timer interface and cancel all pending timers
        // This must happen before context manager deinit to prevent callbacks
        // from firing after the V8 context is disposed
        clearTimerInterface();

        // Clean up all registered CallbackWrappers (EventListener, etc.)
        // This must happen before V8 context disposal to properly release Global handles
        callback_registry.deinit();

        // Clear iframe src load hook to prevent callbacks after context disposal
        impls.HTMLIFrameElement.setIframeSrcLoadHook(null);

        // NOTE: Do NOT explicitly deinit singleton instances here!
        // The context_manager.deinit() below cleans up the wrapper cache,
        // which calls gc.onObjectFreed() for each instance. If we deinit
        // instances here AND the wrapper cache also deinits them, we get
        // double-free crashes. Let the wrapper cache handle all cleanup.
        self.document_instance = null;
        self.navigator_instance = null;
        self.location_instance = null;
        self.history_instance = null;
        self.performance_instance = null;

        // Remove this context from the context manager (cleans up wrapper cache for this context)
        // NOTE: Use removeContext() instead of deinit() - deinit() destroys the entire
        // context manager which causes memory leaks when navigating between pages.
        // The context manager should persist across navigations; only individual contexts
        // should be removed.
        if (self.v8_context) |ctx| {
            context_manager.removeContext(ctx);

            // Exit and dispose V8 context
            v8.ffi.v8_Context_Exit(ctx);
            v8.ffi.v8_Context_Dispose(ctx);
        }

        self.allocator.free(self.url);
        self.initialized = false;
    }
};

// ============================================================================
// V8 Callback Implementations
// ============================================================================

/// setTimeout callback - schedules callback to run after delay using TimerManager
fn setTimeoutCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Get the callback function (first argument)
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    const callback_value = info.get(0);
    if (!v8.ffi.v8_Value_IsFunction(callback_value)) {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    // Get delay (second argument, default 0)
    var delay_ms: i64 = 0;
    if (info.v8_FunctionCallbackInfo_Length() >= 2) {
        const delay_value = info.get(1);
        if (v8.ffi.v8_Value_IsNumber(delay_value)) {
            const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
                const result = v8.ffi.v8_Integer_New(isolate, 0);
                info.setReturnValue(@ptrCast(result));
                return;
            };
            const delay_f64 = v8.ffi.v8_Value_NumberValue(delay_value, context);
            // Safety check for NaN/Inf/negative values
            if (!std.math.isNan(delay_f64) and !std.math.isInf(delay_f64) and delay_f64 >= 0 and delay_f64 <= @as(f64, @floatFromInt(std.math.maxInt(i64)))) {
                delay_ms = @intFromFloat(delay_f64);
            }
        }
    }

    // Get timer interface from thread-local storage
    const timer = getTimerInterface() orelse {
        // Fallback: execute immediately if no timer interface
        const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
            const result = v8.ffi.v8_Integer_New(isolate, 0);
            info.setReturnValue(@ptrCast(result));
            return;
        };
        const callback_fn: *v8.ffi.Function = @ptrCast(callback_value);
        const global = v8.ffi.v8_Context_Global(context) orelse {
            const result = v8.ffi.v8_Integer_New(isolate, 0);
            info.setReturnValue(@ptrCast(result));
            return;
        };
        var empty_args: [1]*v8.ffi.Value = undefined;
        _ = v8.ffi.v8_Function_Call(callback_fn, context, @ptrCast(global), 0, &empty_args);
        const result = v8.ffi.v8_Integer_New(isolate, 1);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Use page_allocator for timer wrappers - they must outlive the current arena
    // because timers fire asynchronously after the current operation completes
    const timer_allocator = std.heap.page_allocator;

    // Create typed timer context wrapper (one-shot timer)
    const timer_wrapper = createV8TimerContext(timer_allocator, isolate, callback_value, false) catch {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Schedule the timer using TimerInterface with typed callback trampoline
    const delay_u64: u64 = if (delay_ms >= 0) @intCast(delay_ms) else 0;

    // Debug: log 0ms timers as they may be important for testharness.js completion
    if (delay_u64 == 0) {
        std.debug.print("[setTimeout] 0ms timer scheduled (testharness completion?)\n", .{});
    }
    const timer_id = timer.setTimeout(
        delay_u64,
        V8TimerCallback.getTrampolineCallback(),
        timer_wrapper.eraseForFFI(),
    );
    if (timer_id == 0) {
        timer_wrapper.destroy();
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    // Store the timer ID in the context so the callback can unregister it
    timer_wrapper.getData().current_timer_id = timer_id;

    // Register the timer context for cleanup tracking (prevents memory leak on deinit)
    registerTimerContext(timer_id, timer_wrapper);

    // Return timer ID (truncate to i32 for V8 Integer)
    const result = v8.ffi.v8_Integer_New(isolate, @intCast(@as(u32, @truncate(timer_id))));
    info.setReturnValue(@ptrCast(result));
}

/// clearTimeout callback - cancels a pending timer
fn clearTimeoutCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Get timer ID (first argument)
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    }

    const id_value = info.get(0);
    if (!v8.ffi.v8_Value_IsNumber(id_value)) {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    }

    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };

    const timer_id_f64 = v8.ffi.v8_Value_NumberValue(id_value, context);

    // Safety check: ensure the float is a valid positive integer that fits in TimerId
    if (std.math.isNan(timer_id_f64) or std.math.isInf(timer_id_f64) or
        timer_id_f64 < 0 or timer_id_f64 > @as(f64, @floatFromInt(std.math.maxInt(TimerId))))
    {
        // Invalid timer ID - just return without doing anything
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    }
    const timer_id: TimerId = @intFromFloat(timer_id_f64);

    // Get timer interface and cancel the timer
    if (getTimerInterface()) |timer| {
        timer.clearTimeout(timer_id);
    }

    // Clean up interval context if this was an interval timer
    // (clearTimeout and clearInterval use the same underlying mechanism)
    unregisterTimerContext(timer_id);

    if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
        info.setReturnValue(undef_value);
    }
}

/// setInterval callback - schedules repeating callback using TimerManager
fn setIntervalCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Get the callback function (first argument)
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    const callback_value = info.get(0);
    if (!v8.ffi.v8_Value_IsFunction(callback_value)) {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    // Get delay (second argument, default 0)
    var delay_ms: i64 = 0;
    if (info.v8_FunctionCallbackInfo_Length() >= 2) {
        const delay_value = info.get(1);
        if (v8.ffi.v8_Value_IsNumber(delay_value)) {
            const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
                const result = v8.ffi.v8_Integer_New(isolate, 0);
                info.setReturnValue(@ptrCast(result));
                return;
            };
            const delay_f64 = v8.ffi.v8_Value_NumberValue(delay_value, context);
            // Safety check for NaN/Inf/negative values
            if (!std.math.isNan(delay_f64) and !std.math.isInf(delay_f64) and delay_f64 >= 0 and delay_f64 <= @as(f64, @floatFromInt(std.math.maxInt(i64)))) {
                delay_ms = @intFromFloat(delay_f64);
            }
        }
    }

    // Get timer interface from thread-local storage
    const timer = getTimerInterface() orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Use page_allocator for timer wrappers - they must outlive the current arena
    // because timers fire asynchronously after the current operation completes
    const timer_allocator = std.heap.page_allocator;

    // Create typed timer context wrapper (interval timer)
    const timer_wrapper = createV8TimerContext(timer_allocator, isolate, callback_value, true) catch {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Store the interval delay in the context for re-scheduling
    const delay_u64: u64 = if (delay_ms >= 0) @intCast(delay_ms) else 0;
    timer_wrapper.getData().interval_delay_ms = delay_u64;

    // Schedule the first timeout (intervals reschedule themselves in v8IntervalHandler)
    const timer_id = timer.setTimeout(
        delay_u64,
        V8TimerCallback.getTrampolineCallback(),
        timer_wrapper.eraseForFFI(),
    );
    if (timer_id == 0) {
        timer_wrapper.destroy();
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    // Store the timer ID in the context so it can be used for rescheduling
    timer_wrapper.getData().current_timer_id = timer_id;

    // Register the interval context for cleanup when clearInterval is called
    registerTimerContext(timer_id, timer_wrapper);

    // Return timer ID (truncate to i32 for V8 Integer)
    const result = v8.ffi.v8_Integer_New(isolate, @intCast(@as(u32, @truncate(timer_id))));
    info.setReturnValue(@ptrCast(result));
}

// NOTE: addEventListenerCallback, removeEventListenerCallback, and dispatchEventCallback
// have been removed. These were NOOP stubs that overwrote the proper WebIDL EventTarget
// bindings. The EventTarget implementation in src/webidl/impls/EventTarget.zig now
// provides the actual functionality via the standard WebIDL interface system.

// NOTE: getComputedStyleCallback, getPropertyValueCallback, and fetchCallback stubs
// have been removed. These functions are now provided by the proper WebIDL implementations
// via Window.registerMethodsAsOwnOnObject() which delegates to the Window interface.

// ============================================================================
// Child Context Globals Registration
// ============================================================================

/// Register browser-level globals on a child context (iframe).
/// This is called by context_manager.createChildContext via the
/// setChildContextGlobalsCallback hook.
///
/// Registers: setTimeout, clearTimeout, setInterval, clearInterval
///
/// Note: This uses the same callbacks as registerCommonGlobals but
/// can be called standalone for child contexts created by context_manager.
pub fn registerTimerGlobalsOnContext(
    isolate: *v8.ffi.Isolate,
    v8_ctx: *v8.ffi.Context,
    global_obj: *v8.ffi.Object,
) void {
    // setTimeout
    {
        const template = v8.ffi.v8_FunctionTemplate_New(isolate, setTimeoutCallback, null) orelse return;
        v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
        const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return;
        const key = v8.ffi.v8_String_NewFromUtf8(isolate, "setTimeout", 10) orelse return;
        _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
    }

    // clearTimeout
    {
        const template = v8.ffi.v8_FunctionTemplate_New(isolate, clearTimeoutCallback, null) orelse return;
        v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
        const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return;
        const key = v8.ffi.v8_String_NewFromUtf8(isolate, "clearTimeout", 12) orelse return;
        _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
    }

    // setInterval
    {
        const template = v8.ffi.v8_FunctionTemplate_New(isolate, setIntervalCallback, null) orelse return;
        v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
        const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return;
        const key = v8.ffi.v8_String_NewFromUtf8(isolate, "setInterval", 11) orelse return;
        _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
    }

    // clearInterval (uses same callback as clearTimeout)
    {
        const template = v8.ffi.v8_FunctionTemplate_New(isolate, clearTimeoutCallback, null) orelse return;
        v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
        const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return;
        const key = v8.ffi.v8_String_NewFromUtf8(isolate, "clearInterval", 13) orelse return;
        _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
    }
}
