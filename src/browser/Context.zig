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
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const namespaces = @import("namespaces");
const fetch = @import("fetch");

const storage_mod = @import("storage/Storage.zig");
const Storage = storage_mod.Storage;
const navigation = @import("navigation.zig");
const context_manager = v8.context_manager;
const impls = @import("impls");

// Threadlocal state cleanup modules
const dom_mod = @import("dom");
const html_mod = @import("html");
const custom_elements = html_mod.custom_elements;
const mutation_observer_algorithms = dom_mod.mutation_observer_algorithms;
const instance_lifecycle = runtime.instance_lifecycle;

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
            // Mark as cancelled so interval callbacks know to stop rescheduling
            wrapper.getData().cancelled = true;
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
/// This works for short-lived tests but could cause issues if V8 GCs
/// the function before the timer fires. For production use, the V8 FFI
/// would need to expose v8::Global<v8::Function> creation.
///
/// NOTE: This stores raw V8 function pointers without proper persistent handles.
/// The V8 FFI doesn't currently support Persistent/Global handle creation.
const V8TimerContextData = struct {
    /// Raw pointer to the V8 function (not GC-protected!)
    callback_fn: *v8.ffi.Function,
    /// V8 isolate
    isolate: *v8.ffi.Isolate,
    /// V8 context (needed because timer callbacks fire outside of active context)
    v8_context: *v8.ffi.Context,
    /// Whether this is an interval (repeating) timer - affects cleanup
    is_interval: bool,
    /// For intervals: the delay in ms for rescheduling
    interval_delay_ms: u64 = 0,
    /// For intervals: the current timer ID (updated on each reschedule)
    current_timer_id: TimerId = 0,
    /// For intervals: whether the interval has been cancelled
    cancelled: bool = false,
};

/// Type-safe timer callback wrapper for V8 timer contexts.
///
/// Uses SelfContainedWorkCallback to bundle the callback function and context data
/// together, providing compile-time type safety and eliminating manual
/// anyopaque casts in callback functions. The work callback variant stores
/// the allocator internally for no-argument destroy().
const V8TimerCallback = SelfContainedWorkCallback(V8TimerContextData);

/// Create a new V8 timer context wrapper
fn createV8TimerContext(allocator: std.mem.Allocator, isolate: *v8.ffi.Isolate, v8_context: *v8.ffi.Context, callback_value: *v8.ffi.Value, is_interval: bool) !*V8TimerCallback {
    // Verify it's a function
    if (!v8.ffi.v8_Value_IsFunction(callback_value)) {
        return error.NotAFunction;
    }

    const callback_fn = if (is_interval) &v8IntervalHandler else &v8TimerHandler;
    return try V8TimerCallback.create(
        allocator,
        callback_fn,
        .{
            .callback_fn = @ptrCast(callback_value),
            .isolate = isolate,
            .v8_context = v8_context,
            .is_interval = is_interval,
        },
    );
}

/// Handler function for one-shot timer callbacks (invoked via SelfContainedCallback trampoline)
fn v8TimerHandler(data: *V8TimerContextData) void {
    // Unregister from timer_contexts map before destroying (prevents double-free on deinit)
    if (timer_contexts) |*map| {
        _ = map.remove(data.current_timer_id);
    }

    const isolate = data.isolate;
    const context = data.v8_context;

    // Enter the V8 context before invoking the callback
    // Timer callbacks fire from the event loop when no context is active
    v8.ffi.v8_Context_Enter(context);
    defer v8.ffi.v8_Context_Exit(context);

    const global = v8.ffi.v8_Context_Global(context) orelse {
        return;
    };

    // Invoke the V8 function (stored directly, not via persistent handle)
    var empty_args: [1]*v8.ffi.Value = undefined;
    _ = v8.ffi.v8_Function_Call(data.callback_fn, context, @ptrCast(global), 0, &empty_args);

    // Run microtasks after the timer callback (per event loop semantics)
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

    // Destroy the wrapper - this is a one-shot timer, so clean up after execution
    // Get the wrapper pointer from the data pointer (data is embedded in SelfContainedCallback)
    const wrapper: *V8TimerCallback = @fieldParentPtr("data", data);
    wrapper.destroy();
}

/// Handler function for interval callbacks (invoked via SelfContainedCallback trampoline)
fn v8IntervalHandler(data: *V8TimerContextData) void {
    // Check if interval was cancelled
    if (data.cancelled) {
        if (timer_contexts) |*map| {
            _ = map.remove(data.current_timer_id);
        }
        return;
    }

    const isolate = data.isolate;
    const context = data.v8_context;

    // Enter the V8 context before invoking the callback
    // Timer callbacks fire from the event loop when no context is active
    v8.ffi.v8_Context_Enter(context);
    defer v8.ffi.v8_Context_Exit(context);

    const global = v8.ffi.v8_Context_Global(context) orelse return;

    // Invoke the V8 function
    var empty_args: [1]*v8.ffi.Value = undefined;
    _ = v8.ffi.v8_Function_Call(data.callback_fn, context, @ptrCast(global), 0, &empty_args);

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

    // Singleton instances for cleanup
    window_instance: ?*runtime.Instance = null,
    document_instance: ?*runtime.Instance = null,
    navigator_instance: ?*runtime.Instance = null,
    location_instance: ?*runtime.Instance = null,
    history_instance: ?*runtime.Instance = null,
    performance_instance: ?*runtime.Instance = null,

    // Debug counter for tracking context lifecycle
    var context_id_counter: u32 = 0;

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
    ) !*Context {
        context_id_counter += 1;
        const ctx_id = context_id_counter;
        std.debug.print("\n[Context.init] === Creating context #{d} ===\n", .{ctx_id});
        std.debug.print("[Context.init] URL: {s}\n", .{url});
        std.debug.print("[Context.init] Isolate: {*}\n", .{isolate});

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
            v8_ctx = v8.ffi.v8_Context_NewFromSnapshot(self.isolate) orelse {
                // Fallback to slow path if snapshot context fails
                std.debug.print("Warning: Snapshot context failed, falling back to fresh context\n", .{});
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

        // Register context with context manager for wrapper caching
        // Pass timer and event loop interfaces so all runtime contexts share the same libuv loop
        const timer_iface = if (self.event_loop) |ev| ev.timerInterface() else null;
        const event_loop_iface = if (self.event_loop) |ev| ev.eventLoop() else null;
        const runtime_ctx = context_manager.getOrCreateWithExternalEventLoop(v8_ctx, timer_iface, event_loop_iface, self.allocator) catch |err| {
            std.debug.print("Warning: Context registration failed: {}\n", .{err});
            return error.ContextRegistrationFailed;
        };

        // SNAPSHOT MODE: Skip initializeBindings() - interfaces are already in the snapshot!
        // However, we still need to populate the Zig-side template registry so that
        // wrapInstanceAsV8Object() can wrap Document, Navigator, etc. with correct prototypes.
        v8.interface_bindings.registerAllTemplatesOnly(self.isolate, v8_ctx);

        // Register namespaces (console, WebAssembly, etc.) which are NOT included in the snapshot.
        v8.interface_bindings.registerNamespacesGeneric(namespaces, self.isolate, v8_ctx);

        // Get the global object
        const global = v8.ffi.v8_Context_Global(v8_ctx) orelse {
            return error.NoGlobal;
        };

        // Fix Window instanceof by patching Window[Symbol.hasInstance].
        // V8 snapshots don't preserve the identity between Function.prototype and
        // objects in the prototype chain. So after snapshot restore, Window.prototype
        // is a different object than what's in global's prototype chain.
        //
        // Instead of trying to fix the prototype identity (which V8 prevents),
        // we patch Symbol.hasInstance to check the internal type info, which IS
        // correctly preserved in the snapshot.
        v8.ffi.v8_PatchWindowInstanceOf(self.isolate, v8_ctx, global);

        // Patch Document[Symbol.hasInstance] for cross-context instanceof checks.
        // When iframe.contentDocument is accessed from this context, the returned
        // Document is from the child context with a different prototype chain.
        // This custom Symbol.hasInstance checks the internal type info instead.
        v8.ffi.v8_PatchDocumentInstanceOf(self.isolate, v8_ctx, global);

        // Patch Event[Symbol.hasInstance] for event instanceof checks.
        // V8 snapshots don't preserve prototype identity, so event objects created
        // and dispatched within the runtime fail instanceof Event checks.
        v8.ffi.v8_PatchEventInstanceOf(self.isolate, v8_ctx, global);

        // Create and bind Window instance to global object's internal fields
        // This is required for WebIDL method callbacks to extract the Zig instance from `this`
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

        // NOTE: Window is stored in global's internal field 0, so context_manager.getWindowForContext()
        // can find it via getWindowFromGlobalInternalField() fallback. No need to call setWindowForContext().

        // Register Window in wrapper cache for proper cleanup
        if (runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
            const cache: *v8.wrapper_cache_mod.WrapperCache = @ptrCast(@alignCast(cache_storage));
            cache.set(window_instance, global, self.isolate) catch {};
        }

        // Register Window properties (document, navigator, etc.) as own properties on the global object.
        // This is required because the global's prototype is immutable (set via SetImmutableProto),
        // so we can't inherit properties from Window.prototype through the prototype chain.
        // This matches how child contexts (iframes) register Window properties.
        v8.interface_bindings.Window.registerPropertiesAsOwnOnObject(self.isolate, v8_ctx, global);

        // Register Window methods (queueMicrotask, setTimeout, etc.) as own properties on the global object.
        // Per WebIDL §3.8: For [Global] interfaces, the global object should have
        // the interface's operations as own properties (callable functions).
        v8.interface_bindings.Window.registerMethodsAsOwnOnObject(self.isolate, v8_ctx, global);

        // Also register EventTarget methods (addEventListener, removeEventListener, dispatchEvent)
        // since Window inherits from EventTarget.
        v8.interface_bindings.EventTarget.registerMethodsAsOwnOnObject(self.isolate, v8_ctx, global);

        // Set self/window/frames as data properties equal to global
        // This is critical for testharness.js compatibility: (function(global_scope){...})(self)
        // requires that self === globalThis so that properties set on global_scope become
        // accessible as global variables. These are skipped in registerPropertiesAsOwnOnObject
        // because they need to be data properties (not accessors) for object identity.
        if (v8.ffi.v8_String_NewFromUtf8(self.isolate, "self", 4)) |self_prop_key| {
            _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(self_prop_key), @ptrCast(global));
        }
        if (v8.ffi.v8_String_NewFromUtf8(self.isolate, "window", 6)) |window_prop_key| {
            _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(window_prop_key), @ptrCast(global));
        }
        if (v8.ffi.v8_String_NewFromUtf8(self.isolate, "frames", 6)) |frames_prop_key| {
            _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(frames_prop_key), @ptrCast(global));
        }

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

        // Register context with context manager for wrapper caching
        const timer_iface = if (self.event_loop) |ev| ev.timerInterface() else null;
        const event_loop_iface = if (self.event_loop) |ev| ev.eventLoop() else null;
        const runtime_ctx = context_manager.getOrCreateWithExternalEventLoop(v8_ctx, timer_iface, event_loop_iface, self.allocator) catch |err| {
            std.debug.print("Warning: Context registration failed: {}\n", .{err});
            return error.ContextRegistrationFailed;
        };

        // SLOW PATH: Register all WebIDL interfaces manually
        // This is required for fresh contexts without snapshot
        v8.interface_bindings.initializeBindingsWithGlobalTemplate(self.isolate, v8_ctx);

        // Register all namespaces
        v8.interface_bindings.registerNamespacesGeneric(namespaces, self.isolate, v8_ctx);

        // Get the global object
        const global = v8.ffi.v8_Context_Global(v8_ctx) orelse {
            return error.NoGlobal;
        };

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

        // NOTE: Window is stored in global's internal field 0, so context_manager.getWindowForContext()
        // can find it via getWindowFromGlobalInternalField() fallback. No need to call setWindowForContext().

        // Register Window in wrapper cache
        if (runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
            const cache: *v8.wrapper_cache_mod.WrapperCache = @ptrCast(@alignCast(cache_storage));
            cache.set(window_instance, global, self.isolate) catch {};
        }

        // Register Window properties as own properties on the global object
        v8.interface_bindings.Window.registerPropertiesAsOwnOnObject(self.isolate, v8_ctx, global);

        // Register Window methods (queueMicrotask, setTimeout, etc.) as own properties on the global object.
        // Per WebIDL §3.8: For [Global] interfaces, the global object should have
        // the interface's operations as own properties (callable functions).
        v8.interface_bindings.Window.registerMethodsAsOwnOnObject(self.isolate, v8_ctx, global);

        // Also register EventTarget methods (addEventListener, removeEventListener, dispatchEvent)
        // since Window inherits from EventTarget.
        v8.interface_bindings.EventTarget.registerMethodsAsOwnOnObject(self.isolate, v8_ctx, global);

        // Set self/window/frames as data properties equal to global
        // This is critical for testharness.js compatibility
        if (v8.ffi.v8_String_NewFromUtf8(self.isolate, "self", 4)) |self_prop_key| {
            _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(self_prop_key), @ptrCast(global));
        }
        if (v8.ffi.v8_String_NewFromUtf8(self.isolate, "window", 6)) |window_prop_key| {
            _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(window_prop_key), @ptrCast(global));
        }
        if (v8.ffi.v8_String_NewFromUtf8(self.isolate, "frames", 6)) |frames_prop_key| {
            _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(frames_prop_key), @ptrCast(global));
        }

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
            if (self.window_instance) |win| {
                impls.Window.setDocument(win, doc_instance);
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

        // addEventListener
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, addEventListenerCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 2);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "addEventListener", 16) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // removeEventListener
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, removeEventListenerCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 2);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "removeEventListener", 19) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // dispatchEvent
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, dispatchEventCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "dispatchEvent", 13) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // NOTE: console object is registered via WebIDL namespace binding in snapshot
        // (see bindings.zig initializeNamespaces -> Console.registerGlobal)
        // The native binding provides proper console.log/error/etc with output to stderr

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
                \\      // Use 0 instead of -1 in triplet calculation to prevent corruption
                \\      var triplet = (a << 18) | (b << 12) | ((c === -1 ? 0 : c) << 6) | (d === -1 ? 0 : d);
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

        // Register getComputedStyle as a global function
        // Per CSSOM spec, window.getComputedStyle(element, pseudoElt) returns computed styles
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, getComputedStyleCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "getComputedStyle", 16) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // Register fetch() as a global function
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, fetchCallback, null) orelse return error.FunctionTemplateCreateFailed;
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "fetch", 5) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }
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
        };

        _ = self.evaluateScript(setup_script) catch |err| {
            std.debug.print("ERROR: Failed to set up global aliases: {}\n", .{err});
            return err;
        };
    }

    /// Options for loadPage
    pub const LoadPageOptions = struct {
        /// Optional script loader for external scripts
        script_loader: ?ScriptLoader = null,
    };

    /// Load page content (fetch, parse, execute)
    ///
    /// Navigation flow per HTML Standard:
    /// 1. Fetch URL content via HTTP
    /// 2. Parse HTML into DOM tree
    /// 3. Execute inline and external scripts (in document order)
    /// 4. Fire DOMContentLoaded event
    /// 5. Fire load event
    pub fn loadPage(self: *Context) !void {
        return self.loadPageWithOptions(.{});
    }

    /// Load page content with options
    pub fn loadPageWithOptions(self: *Context, options: LoadPageOptions) !void {
        // For about:blank, just return with empty document
        if (std.mem.eql(u8, self.url, "about:blank")) {
            return;
        }

        // Step 1: Fetch URL content via HTTP
        var result = navigation.fetchUrl(self.allocator, self.url, .{}) catch {
            // Handle navigation errors gracefully
            return error.NavigationFailed;
        };
        defer result.deinit();

        // Step 2: Check if HTML content
        const is_html = std.mem.indexOf(u8, result.content_type, "text/html") != null or
            std.mem.indexOf(u8, result.content_type, "application/xhtml") != null;

        if (!is_html) {
            // For non-HTML content, just return
            // This is a simplified approach for now
            return;
        }

        // Step 3-5: Parse HTML and execute scripts using loadHTML
        // This uses the full HTML parser with proper script loading
        try self.loadHTML(result.body, .{
            .base_url = self.url,
            .scripting_enabled = true,
            .script_loader = options.script_loader,
        });
    }

    /// Execute inline scripts from HTML content
    fn executeInlineScripts(self: *Context, html: []const u8) !void {
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        // Simple script extractor - find <script>...</script> blocks
        var pos: usize = 0;
        while (pos < html.len) {
            // Find <script
            const script_start = std.mem.indexOfPos(u8, html, pos, "<script") orelse break;

            // Find > (end of opening tag)
            const tag_end = std.mem.indexOfPos(u8, html, script_start, ">") orelse break;

            // Check if it's a src script (external) - skip those for now
            const tag_attrs = html[script_start..tag_end];
            if (std.mem.indexOf(u8, tag_attrs, " src=") != null or
                std.mem.indexOf(u8, tag_attrs, " src =") != null)
            {
                // External script - skip for now
                // TODO: Fetch and execute external scripts
                pos = tag_end + 1;
                continue;
            }

            // Find </script>
            const script_end = std.mem.indexOfPos(u8, html, tag_end, "</script>") orelse break;

            // Extract script content
            const script_content = html[tag_end + 1 .. script_end];

            if (script_content.len > 0) {
                // Execute the script
                _ = self.evaluateScriptSafe(script_content, isolate, v8_ctx);
            }

            pos = script_end + 9; // Move past </script>
        }
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
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        std.debug.print("loadHTML: Browser.Context v8_context={*}\n", .{v8_ctx});

        // Get runtime context for HTMLParser
        const runtime_ctx = context_manager.getOrCreate(v8_ctx, self.allocator) catch |err| {
            std.debug.print("Failed to get runtime context: {}\n", .{err});
            return error.NotInitialized;
        };

        std.debug.print("loadHTML: runtime_ctx engine_ctx={*}\n", .{runtime_ctx.getEngineContext()});

        // Set the document URL in context_manager for fetch relative URL resolution
        context_manager.setDocumentUrl(v8_ctx, options.base_url) catch |err| {
            std.debug.print("Warning: Failed to set document URL: {}\n", .{err});
        };

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
        navigation.fireDOMContentLoaded(isolate, v8_ctx);

        // Fire load event
        // Per HTML Standard §13.2.7 "The end" step 9
        navigation.fireLoad(isolate, v8_ctx);
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
        defer interfaces.HTMLCollection.deinit(iframes);

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
        // IMPORTANT: Check if url points to self.url (same slice) to avoid use-after-free.
        // This can happen when loadHTML is called with base_url = self.url
        if (url.ptr == self.url.ptr) {
            // URL is already set to this value, nothing to do
            return;
        }
        // Duplicate first, then free old to avoid use-after-free if url somehow
        // references memory that would be affected by the free
        const new_url = try self.allocator.dupe(u8, url);
        self.allocator.free(self.url);
        self.url = new_url;

        // Note: Location object URL is set during context initialization
        // and via JavaScript. Direct impl access would require Location.setHref
        // which isn't currently exposed. For now, the URL is tracked in Context.url.
        _ = self.location_instance;
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
    ///
    /// This implements Chrome's context disposal sequence from LocalWindowProxy::DisposeContext:
    /// 1. Cancel all pending timers (prevents callbacks after disposal)
    /// 2. Clear singleton references
    /// 3. Remove from context manager (cleans up wrapper cache)
    /// 4. DetachGlobal() - break context/global link (Chrome pattern)
    /// 5. Exit context
    /// 6. ContextDisposedNotification() - hint GC (Chrome pattern)
    /// 7. Dispose context handle
    pub fn deinit(self: *Context) void {
        std.debug.print("\n[Context.deinit] === Destroying context ===\n", .{});
        std.debug.print("[Context.deinit] URL: {s}\n", .{self.url});
        std.debug.print("[Context.deinit] V8 Context: {?*}\n", .{self.v8_context});

        // Clean up threadlocal state that accumulates across context navigations.
        // These must be cleaned up to prevent state accumulation that causes
        // timeouts in sequential test execution.

        // Clean up custom elements threadlocal state (reactions_stack, element_reaction_queues)
        custom_elements.deinitThreadLocalState();

        // Clean up mutation observer threadlocal state (global_agent)
        mutation_observer_algorithms.resetAgent();

        // Clear instance lifecycle registry entries
        // (the registry itself persists but entries for this context's instances should be cleaned)
        instance_lifecycle.clearAll();

        // Clear timer interface and cancel all pending timers
        // This must happen before context manager deinit to prevent callbacks
        // from firing after the V8 context is disposed
        clearTimerInterface();

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

            // Chrome-style context disposal sequence:
            // Per Chrome's LocalWindowProxy::DisposeContext, we must:
            // 1. Detach global to break the context/global proxy link
            // 2. Exit the context
            // 3. Notify V8 that a context was disposed (helps GC)
            // 4. Release the persistent handle

            // Step 1: Detach global object from context
            // This breaks the link between the context and its global proxy,
            // preventing JavaScript from accessing the context's global scope
            v8.ffi.v8_Context_DetachGlobal(ctx);

            // Step 2: Exit context
            v8.ffi.v8_Context_Exit(ctx);

            // Step 3: Notify V8 that a context has been disposed
            // This hints to V8's garbage collector that context-associated objects
            // can be collected more eagerly. force_gc=true for aggressive cleanup
            // which is needed for sequential test execution.
            _ = v8.ffi.v8_Isolate_ContextDisposedNotification(self.isolate, true);

            // Step 4: Dispose the persistent context handle
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

    const allocator = current_allocator orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Get the current V8 context - needed for timer callback execution
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Create typed timer context wrapper (one-shot timer)
    const timer_wrapper = createV8TimerContext(allocator, isolate, v8_context, callback_value, false) catch {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Schedule the timer using TimerInterface with typed callback trampoline
    const delay_u64: u64 = if (delay_ms >= 0) @intCast(delay_ms) else 0;
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

    const allocator = current_allocator orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Get the current V8 context - needed for interval callback execution
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Create typed timer context wrapper (interval timer)
    const timer_wrapper = createV8TimerContext(allocator, isolate, v8_context, callback_value, true) catch {
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

/// addEventListener callback - delegates to EventTarget WebIDL implementation
/// Per DOM spec: https://dom.spec.whatwg.org/#dom-eventtarget-addeventlistener
fn addEventListenerCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Return undefined by default
    const return_undefined = v8.ffi.v8_Undefined(isolate) orelse return;
    info.setReturnValue(return_undefined);

    // Get V8 context
    const v8_ctx = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Get global object (which has the window instance)
    const global = v8.ffi.v8_Context_Global(v8_ctx) orelse return;

    // Get window instance from internal field 0
    const window_ptr = v8.ffi.v8_Object_GetAlignedPointerFromInternalField(global, 0) orelse return;
    const window_instance: *runtime.Instance = @ptrCast(@alignCast(window_ptr));

    // Need at least type and callback arguments
    if (info.v8_FunctionCallbackInfo_Length() < 2) return;

    // Get type argument (first arg)
    const type_arg = info.v8_FunctionCallbackInfo_GetArgument(0);
    if (!v8.ffi.v8_Value_IsString(@ptrCast(type_arg))) return;
    const type_str: *v8.ffi.String = @ptrCast(type_arg);

    // Convert V8 string to DOMString
    const type_length = v8.ffi.v8_String_Utf8Length(type_str);
    if (type_length <= 0) return;
    const allocator = std.heap.page_allocator;
    const type_buffer = allocator.alloc(u8, @intCast(type_length)) catch return;
    defer allocator.free(type_buffer);
    _ = v8.ffi.v8_String_WriteUtf8(type_str, type_buffer.ptr, @intCast(type_length));
    const event_type = runtime.DOMString.initOwned(type_buffer);

    // Get callback argument (second arg)
    const callback_arg = info.v8_FunctionCallbackInfo_GetArgument(1);
    if (v8.ffi.v8_Value_IsNullOrUndefined(@ptrCast(callback_arg))) return;

    // Create V8 CallbackWrapper from the callback value
    const v8_wrapper = v8.callback_wrapper_mod.createFromV8Value(
        allocator,
        isolate,
        v8_ctx,
        @ptrCast(callback_arg),
        "handleEvent",
    ) catch return orelse return;

    // Create runtime.CallbackWrapper that wraps the V8 callback
    // (per conversions.zig pattern for proper engine interface setup)
    const runtime_wrapper = allocator.create(runtime.CallbackWrapper) catch {
        v8_wrapper.deinit();
        return;
    };
    runtime_wrapper.* = .{
        .engine_handle = v8_wrapper,
        .engine = &v8.v8_engine_interface,
        .engine_ctx = v8_ctx,
        .allocator = allocator,
    };

    // Call the EventTarget implementation with double-optional callback
    const EventTargetImpl = impls.EventTarget;
    EventTargetImpl.call_addEventListener(
        window_instance,
        event_type,
        @as(?*runtime.CallbackWrapper, runtime_wrapper),
        webidl.Opt(runtime.JSValue).notPassed(),
    ) catch |err| {
        std.debug.print("[addEventListener] Error: {}\n", .{err});
        runtime_wrapper.deinit();
        allocator.destroy(runtime_wrapper);
    };
}

/// removeEventListener callback - delegates to EventTarget WebIDL implementation
/// Per DOM spec: https://dom.spec.whatwg.org/#dom-eventtarget-removeeventlistener
fn removeEventListenerCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Return undefined by default
    const return_undefined = v8.ffi.v8_Undefined(isolate) orelse return;
    info.setReturnValue(return_undefined);

    // Get V8 context
    const v8_ctx = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Get global object (which has the window instance)
    const global = v8.ffi.v8_Context_Global(v8_ctx) orelse return;

    // Get window instance from internal field 0
    const window_ptr = v8.ffi.v8_Object_GetAlignedPointerFromInternalField(global, 0) orelse return;
    const window_instance: *runtime.Instance = @ptrCast(@alignCast(window_ptr));

    // Need at least type and callback arguments
    if (info.v8_FunctionCallbackInfo_Length() < 2) return;

    // Get type argument (first arg)
    const type_arg = info.v8_FunctionCallbackInfo_GetArgument(0);
    if (!v8.ffi.v8_Value_IsString(@ptrCast(type_arg))) return;
    const type_str: *v8.ffi.String = @ptrCast(type_arg);

    // Convert V8 string to DOMString
    const type_length = v8.ffi.v8_String_Utf8Length(type_str);
    if (type_length <= 0) return;
    const allocator = std.heap.page_allocator;
    const type_buffer = allocator.alloc(u8, @intCast(type_length)) catch return;
    defer allocator.free(type_buffer);
    _ = v8.ffi.v8_String_WriteUtf8(type_str, type_buffer.ptr, @intCast(type_length));
    const event_type = runtime.DOMString.initOwned(type_buffer);

    // Get callback argument (second arg)
    const callback_arg = info.v8_FunctionCallbackInfo_GetArgument(1);
    if (v8.ffi.v8_Value_IsNullOrUndefined(@ptrCast(callback_arg))) return;

    // Create V8 CallbackWrapper from the callback value for comparison
    const v8_wrapper = v8.callback_wrapper_mod.createFromV8Value(
        allocator,
        isolate,
        v8_ctx,
        @ptrCast(callback_arg),
        "handleEvent",
    ) catch return orelse return;

    // Create runtime.CallbackWrapper that wraps the V8 callback
    const runtime_wrapper = allocator.create(runtime.CallbackWrapper) catch {
        v8_wrapper.deinit();
        return;
    };
    runtime_wrapper.* = .{
        .engine_handle = v8_wrapper,
        .engine = &v8.v8_engine_interface,
        .engine_ctx = v8_ctx,
        .allocator = allocator,
    };

    // Call the EventTarget implementation with double-optional callback
    const EventTargetImpl = impls.EventTarget;
    EventTargetImpl.call_removeEventListener(
        window_instance,
        event_type,
        @as(?*runtime.CallbackWrapper, runtime_wrapper),
        webidl.Opt(runtime.JSValue).notPassed(),
    ) catch |err| {
        std.debug.print("[removeEventListener] Error: {}\n", .{err});
    };
    // Note: removeEventListener cleans up its own callback wrapper via deinit
}

/// dispatchEvent callback - delegates to EventTarget WebIDL implementation
/// Per DOM spec: https://dom.spec.whatwg.org/#dom-eventtarget-dispatchevent
fn dispatchEventCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Get V8 context
    const v8_ctx = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    };

    // Get global object (which has the window instance)
    const global = v8.ffi.v8_Context_Global(v8_ctx) orelse {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    };

    // Get window instance from internal field 0
    const window_ptr = v8.ffi.v8_Object_GetAlignedPointerFromInternalField(global, 0) orelse {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    };
    const window_instance: *runtime.Instance = @ptrCast(@alignCast(window_ptr));

    // Need at least event argument
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    }

    // Get event argument (first arg)
    const event_arg = info.v8_FunctionCallbackInfo_GetArgument(0);
    if (!v8.ffi.v8_Value_IsObject(@ptrCast(event_arg))) {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    }

    // Get Event instance from internal field 0
    const event_obj: *v8.ffi.Object = @ptrCast(event_arg);
    const event_ptr = v8.ffi.v8_Object_GetAlignedPointerFromInternalField(event_obj, 0) orelse {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    };
    const event_instance: *runtime.Instance = @ptrCast(@alignCast(event_ptr));

    // Call the EventTarget implementation
    const EventTargetImpl = impls.EventTarget;
    const result = EventTargetImpl.call_dispatchEvent(window_instance, event_instance) catch {
        if (v8.ffi.v8_Boolean_New(isolate, false)) |res| {
            info.setReturnValue(res);
        }
        return;
    };

    // Return result
    if (v8.ffi.v8_Boolean_New(isolate, result)) |res| {
        info.setReturnValue(res);
    }
}

/// getComputedStyle callback - returns CSSStyleDeclaration-like object
/// Per CSSOM spec, window.getComputedStyle(element, pseudoElt) returns computed styles
fn getComputedStyleCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_ctx = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Null(isolate)) |null_val| {
            info.setReturnValue(null_val);
        }
        return;
    };

    // Create an empty CSSStyleDeclaration-like object
    // In a full implementation, this would compute styles from the element
    const style_obj = v8.ffi.v8_Object_New(isolate) orelse {
        if (v8.ffi.v8_Null(isolate)) |null_val| {
            info.setReturnValue(null_val);
        }
        return;
    };

    // Add getPropertyValue method
    const get_prop_template = v8.ffi.v8_FunctionTemplate_New(isolate, getPropertyValueCallback, null) orelse {
        info.setReturnValue(@ptrCast(style_obj));
        return;
    };
    const get_prop_func = v8.ffi.v8_FunctionTemplate_GetFunction(get_prop_template, v8_ctx) orelse {
        info.setReturnValue(@ptrCast(style_obj));
        return;
    };
    const get_prop_key = v8.ffi.v8_String_NewFromUtf8(isolate, "getPropertyValue", 16) orelse {
        info.setReturnValue(@ptrCast(style_obj));
        return;
    };
    _ = v8.ffi.v8_Object_Set(style_obj, v8_ctx, @ptrCast(get_prop_key), @ptrCast(get_prop_func));

    // Add length property (0 for stub)
    const length_key = v8.ffi.v8_String_NewFromUtf8(isolate, "length", 6) orelse {
        info.setReturnValue(@ptrCast(style_obj));
        return;
    };
    const length_val = v8.ffi.v8_Integer_New(isolate, 0);
    _ = v8.ffi.v8_Object_Set(style_obj, v8_ctx, @ptrCast(length_key), @ptrCast(length_val));

    info.setReturnValue(@ptrCast(style_obj));
}

/// getPropertyValue helper for CSSStyleDeclaration
fn getPropertyValueCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    // Return empty string for any property (stub implementation)
    const empty_str = v8.ffi.v8_String_NewFromUtf8(isolate, "", 0) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };
    info.setReturnValue(@ptrCast(empty_str));
}

/// fetch callback - implements the global fetch() function
/// Per Fetch spec: https://fetch.spec.whatwg.org/#fetch-method
fn fetchCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_ctx = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        throwTypeError(isolate, info, "No context available");
        return;
    };

    // Get allocator from thread-local storage
    const allocator = current_allocator orelse {
        throwTypeError(isolate, info, "No allocator available");
        return;
    };

    // Create a Promise to return
    const resolver = v8.ffi.v8_PromiseResolver_New(v8_ctx) orelse {
        throwTypeError(isolate, info, "Failed to create promise");
        return;
    };
    const promise = v8.ffi.v8_PromiseResolver_GetPromise(resolver) orelse {
        throwTypeError(isolate, info, "Failed to get promise");
        return;
    };

    // Return the promise early - we'll resolve/reject it after fetch completes
    info.setReturnValue(@ptrCast(promise));

    // Check for URL argument
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        rejectWithTypeError(isolate, v8_ctx, resolver, "Failed to execute 'fetch': 1 argument required, but only 0 present.");
        return;
    }

    // Get URL from first argument
    const url_value = info.get(0);
    if (!v8.ffi.v8_Value_IsString(url_value)) {
        // TODO: Handle Request object input
        rejectWithTypeError(isolate, v8_ctx, resolver, "Failed to execute 'fetch': URL must be a string");
        return;
    }

    // Convert V8 string to Zig string
    const url_str = v8.ffi.v8_Value_ToString(url_value, v8_ctx) orelse {
        rejectWithTypeError(isolate, v8_ctx, resolver, "Failed to convert URL to string");
        return;
    };
    const url_len = v8.ffi.v8_String_Utf8Length(url_str);
    if (url_len <= 0 or url_len > 65536) {
        rejectWithTypeError(isolate, v8_ctx, resolver, "Invalid URL length");
        return;
    }

    const url_buffer = allocator.alloc(u8, @intCast(url_len)) catch {
        rejectWithTypeError(isolate, v8_ctx, resolver, "Out of memory");
        return;
    };
    defer allocator.free(url_buffer);

    const written = v8.ffi.v8_String_WriteUtf8(url_str, url_buffer.ptr, @intCast(url_len));
    if (written <= 0) {
        rejectWithTypeError(isolate, v8_ctx, resolver, "Failed to read URL string");
        return;
    }
    const url_slice = url_buffer[0..@intCast(written)];

    // Resolve relative URLs against the document URL
    var resolved_url: []const u8 = url_slice;
    var resolved_url_owned = false;
    defer if (resolved_url_owned) allocator.free(resolved_url);

    if (std.mem.indexOf(u8, url_slice, "://") == null) {
        // Relative URL - resolve against document URL
        if (context_manager.getDocumentUrl(v8_ctx)) |doc_url| {
            // Find the last slash to get the base directory
            if (std.mem.lastIndexOf(u8, doc_url, "/")) |last_slash| {
                // Special handling for root-relative URLs
                if (url_slice.len > 0 and url_slice[0] == '/') {
                    // Extract origin (scheme + host) from document URL
                    if (std.mem.indexOf(u8, doc_url, "://")) |scheme_end| {
                        const after_scheme = doc_url[scheme_end + 3 ..];
                        if (std.mem.indexOf(u8, after_scheme, "/")) |host_end| {
                            const origin = doc_url[0 .. scheme_end + 3 + host_end];
                            resolved_url = std.fmt.allocPrint(allocator, "{s}{s}", .{ origin, url_slice }) catch {
                                rejectWithTypeError(isolate, v8_ctx, resolver, "Failed to resolve URL");
                                return;
                            };
                            resolved_url_owned = true;
                        }
                    }
                } else {
                    // Relative path - append to base directory
                    const base_dir = doc_url[0 .. last_slash + 1];
                    resolved_url = std.fmt.allocPrint(allocator, "{s}{s}", .{ base_dir, url_slice }) catch {
                        rejectWithTypeError(isolate, v8_ctx, resolver, "Failed to resolve URL");
                        return;
                    };
                    resolved_url_owned = true;
                }
            }
        }
    }

    // Create internal request
    const internal_request = fetch.internal.InternalRequest.init(allocator, resolved_url) catch {
        rejectWithTypeError(isolate, v8_ctx, resolver, "Failed to create request");
        return;
    };
    defer internal_request.deinit();

    // Execute fetch algorithm (synchronous for now)
    var fetch_result = fetch.algorithms.fetch(allocator, internal_request, .{}) catch |err| {
        const err_msg = switch (err) {
            fetch.algorithms.FetchError.NetworkError => "NetworkError: Failed to fetch",
            fetch.algorithms.FetchError.AbortError => "AbortError: Fetch aborted",
            fetch.algorithms.FetchError.OutOfMemory => "OutOfMemory",
        };
        rejectWithTypeError(isolate, v8_ctx, resolver, err_msg);
        return;
    };
    defer fetch_result.timing_info.deinit();

    // Get the runtime context from context_manager (properly managed, tied to V8 context)
    // This ensures the context lives as long as the V8 context and has engine support
    const runtime_ctx = context_manager.getOrCreateWithIsolate(v8_ctx, isolate, allocator) catch {
        fetch_result.response.deinit();
        rejectWithTypeError(isolate, v8_ctx, resolver, "Failed to get runtime context");
        return;
    };

    // Create Response WebIDL wrapper from internal response
    const ResponseImpl = impls.Response;
    const response_instance = ResponseImpl.fromInternalResponse(allocator, fetch_result.response, runtime_ctx) catch {
        fetch_result.response.deinit();
        rejectWithTypeError(isolate, v8_ctx, resolver, "Failed to create Response object");
        return;
    };
    // Note: response_instance now owns fetch_result.response, don't deinit it separately

    // Wrap the Response instance for V8
    const response_js = v8.conversions.instanceToV8(isolate, response_instance);

    // Resolve the promise with the Response
    _ = v8.ffi.v8_PromiseResolver_Resolve(resolver, v8_ctx, response_js);
}

/// Helper to throw TypeError
fn throwTypeError(isolate: *v8.ffi.Isolate, info: *const v8.ffi.FunctionCallbackInfo, msg: []const u8) void {
    const error_msg = v8.ffi.v8_String_NewFromUtf8(isolate, msg.ptr, @intCast(msg.len)) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };
    const error_val = v8.ffi.v8_Exception_TypeError(@ptrCast(error_msg)) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef| {
            info.setReturnValue(undef);
        }
        return;
    };
    v8.ffi.v8_Isolate_ThrowException(isolate, error_val);
}

/// Helper to reject a promise with TypeError
fn rejectWithTypeError(isolate: *v8.ffi.Isolate, v8_ctx: *v8.ffi.Context, resolver: *v8.ffi.PromiseResolver, msg: []const u8) void {
    const error_msg = v8.ffi.v8_String_NewFromUtf8(isolate, msg.ptr, @intCast(msg.len)) orelse return;
    const error_val = v8.ffi.v8_Exception_TypeError(@ptrCast(error_msg)) orelse return;
    _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_ctx, error_val);
}
