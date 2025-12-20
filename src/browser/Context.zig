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
fn createV8TimerContext(allocator: std.mem.Allocator, isolate: *v8.ffi.Isolate, callback_value: *v8.ffi.Value, is_interval: bool) !*V8TimerCallback {
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
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    const global = v8.ffi.v8_Context_Global(context) orelse return;

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
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
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
    pub fn init(
        allocator: std.mem.Allocator,
        isolate: *v8.ffi.Isolate,
        storage: *Storage,
        url: []const u8,
        event_loop: ?*v8.V8EventLoop,
    ) !*Context {
        const ctx = try allocator.create(Context);
        errdefer allocator.destroy(ctx);

        ctx.* = Context{
            .allocator = allocator,
            .isolate = isolate,
            .v8_context = null,
            .storage = storage,
            .url = try allocator.dupe(u8, url),
            .context_type = .window, // Default to window context
            .initialized = false,
            .event_loop = event_loop,
        };

        try ctx.createV8Context();
        return ctx;
    }

    /// Create V8 context and register globals
    /// Per WebIDL spec, creates context with Window's instance template for proper:
    /// - Immutable prototype (Object.setPrototypeOf(window, {}) throws)
    /// - Indexed property handler for frames[index] access
    /// - Internal fields for Window instance binding
    fn createV8Context(self: *Context) !void {
        // Create V8 context with Window's instance template as global template
        // This ensures the global object has all Window properties AND an immutable prototype
        const window_tpl = v8.interface_bindings.Window.createTemplate(self.isolate);
        const global_template = v8.ffi.v8_FunctionTemplate_InstanceTemplate(window_tpl);

        // Mark global object prototype as immutable per WebIDL §3.8
        // Object.setPrototypeOf(window, {}) must throw TypeError
        v8.ffi.v8_ObjectTemplate_SetImmutableProto(global_template);

        // Set internal field count for Window binding (2 fields: impl pointer + type info)
        // This is required for bindWindowToContext() to bind the Window instance to the global
        v8.ffi.v8_ObjectTemplate_SetInternalFieldCount(global_template, 2);

        // Set up indexed property handler for frames[index] access
        // Per HTML spec §7.4.3.1 (WindowProxy [[GetOwnProperty]]):
        // - Numeric indices return child browsing context Windows
        v8.ffi.v8_ObjectTemplate_SetIndexedPropertyHandlerFull(
            global_template,
            context_manager.windowIndexedPropertyGetter,
            null, // setter - not needed
            context_manager.windowIndexedPropertyQuery,
            context_manager.windowIndexedPropertyEnumerator,
            null, // descriptor callback - not needed for basic access
        );

        // Create V8 context with the configured global template
        const v8_ctx = v8.ffi.v8_Context_NewWithGlobalTemplate(self.isolate, global_template) orelse {
            return error.ContextCreateFailed;
        };
        self.v8_context = v8_ctx;

        v8.ffi.v8_Context_Enter(v8_ctx);

        // Initialize context manager for V8 callbacks
        context_manager.init(self.allocator) catch |err| {
            std.debug.print("Warning: Context manager init failed: {}\n", .{err});
        };

        // Register context with context manager for wrapper caching
        // Pass timer and event loop interfaces so all runtime contexts share the same libuv loop
        const timer_iface = if (self.event_loop) |ev| ev.timerInterface() else null;
        const event_loop_iface = if (self.event_loop) |ev| ev.eventLoop() else null;
        _ = context_manager.getOrCreateWithExternalEventLoop(v8_ctx, timer_iface, event_loop_iface, self.allocator) catch |err| {
            std.debug.print("Warning: Context registration failed: {}\n", .{err});
        };

        // Register all WebIDL interfaces
        // This also inserts WindowProperties into Window.prototype's chain via
        // insertIntoPrototypeChain(), creating:
        //   Window.prototype → WindowProperties → EventTarget.prototype
        v8.interface_bindings.initializeBindings(self.isolate, v8_ctx);

        // Register all namespaces
        v8.interface_bindings.registerNamespacesGeneric(namespaces, self.isolate, v8_ctx);

        // Bind Window instance to context for cross-realm support (frames[0], contentWindow)
        // This creates a Window runtime.Instance and binds it to the V8 global object.
        // Must be done after interface bindings are initialized.
        self.window_instance = context_manager.bindWindowToContext(v8_ctx, self.isolate, self.allocator) catch |err| blk: {
            std.debug.print("Warning: Failed to bind Window to context: {}\n", .{err});
            break :blk null;
        };

        // Set the realm's global_object for cross-realm support
        // This enables DOMParser.parseFromString to inherit the document URL from its realm
        if (self.window_instance) |win| {
            if (win.ctx.realm) |realm| {
                realm.global_object = win;
            }
        }

        // Register Window properties as own properties on the global object.
        // This is required for WebIDL compliance: window.length, window.name, etc.
        // must be accessible as own properties via Object.getOwnPropertyDescriptor.
        const global = v8.ffi.v8_Context_Global(v8_ctx);
        if (global) |global_obj| {
            v8.interface_bindings.Window.registerPropertiesAsOwnOnObject(self.isolate, v8_ctx, global_obj);
        }

        // Set up global aliases FIRST (creates __internal object and accessor properties)
        // This must happen before registerBrowserGlobals() which stores singletons in __internal
        try self.setupGlobalAliases();

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

            const v8_navigator = v8.template_registry.wrapInstanceAsV8Object(
                nav_instance,
                "Navigator",
                isolate,
                v8_ctx,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap navigator: {}\n", .{err});
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

            const v8_location = v8.template_registry.wrapInstanceAsV8Object(
                loc_instance,
                "Location",
                isolate,
                v8_ctx,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap location: {}\n", .{err});
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

            const v8_history = v8.template_registry.wrapInstanceAsV8Object(
                hist_instance,
                "History",
                isolate,
                v8_ctx,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap history: {}\n", .{err});
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

            const v8_performance = v8.template_registry.wrapInstanceAsV8Object(
                perf_instance,
                "Performance",
                isolate,
                v8_ctx,
            ) catch |err| {
                std.debug.print("Warning: Failed to wrap performance: {}\n", .{err});
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

        // Register console object with proper WebIDL namespace semantics
        // Per WebIDL spec §3.8.1 "Namespace objects":
        // - The prototype chain is: console -> empty object -> Object.prototype
        // - The namespace has Symbol.toStringTag = "console" (non-writable, non-enumerable, configurable)
        // - All console methods are own properties
        {
            const console_script =
                \\(function() {
                \\  function consoleNoop() {}
                \\  
                \\  // Helper to convert label to string per WHATWG Console Standard
                \\  function convertLabel(label) {
                \\    if (label === undefined) {
                \\      return "default";
                \\    }
                \\    if (label !== null && typeof label === "object") {
                \\      return label.toString();
                \\    }
                \\    return String(label);
                \\  }
                \\  
                \\  // Internal state for count and time operations
                \\  var countMap = {};
                \\  var timerMap = {};
                \\  
                \\  // Create the empty prototype object
                \\  var consoleProto = Object.create(Object.prototype);
                \\  Object.freeze(consoleProto);
                \\  
                \\  // Create console object with the proper prototype chain
                \\  globalThis.console = Object.create(consoleProto);
                \\  
                \\  // Define all console methods as own properties
                \\  var methods = {
                \\    log: consoleNoop,
                \\    warn: consoleNoop,
                \\    error: consoleNoop,
                \\    info: consoleNoop,
                \\    debug: consoleNoop,
                \\    trace: consoleNoop,
                \\    dir: consoleNoop,
                \\    dirxml: consoleNoop,
                \\    table: consoleNoop,
                \\    assert: consoleNoop,
                \\    clear: consoleNoop,
                \\    group: consoleNoop,
                \\    groupCollapsed: consoleNoop,
                \\    groupEnd: consoleNoop,
                \\  };
                \\  
                \\  function createLabelMethod(fn, length) {
                \\    Object.defineProperty(fn, 'length', { value: length, configurable: true });
                \\    return fn;
                \\  }
                \\  
                \\  methods.count = createLabelMethod(function(label) {
                \\    var key = convertLabel(label);
                \\    countMap[key] = (countMap[key] || 0) + 1;
                \\  }, 0);
                \\  
                \\  methods.countReset = createLabelMethod(function(label) {
                \\    var key = convertLabel(label);
                \\    delete countMap[key];
                \\  }, 0);
                \\  
                \\  methods.time = createLabelMethod(function(label) {
                \\    var key = convertLabel(label);
                \\    if (!(key in timerMap)) {
                \\      timerMap[key] = Date.now();
                \\    }
                \\  }, 0);
                \\  
                \\  methods.timeLog = createLabelMethod(function(label) {
                \\    var key = convertLabel(label);
                \\  }, 0);
                \\  
                \\  methods.timeEnd = createLabelMethod(function(label) {
                \\    var key = convertLabel(label);
                \\    delete timerMap[key];
                \\  }, 0);
                \\  
                \\  for (var name in methods) {
                \\    Object.defineProperty(globalThis.console, name, {
                \\      value: methods[name],
                \\      writable: true,
                \\      enumerable: true,
                \\      configurable: true
                \\    });
                \\  }
                \\  
                \\  // Add Symbol.toStringTag per WebIDL namespace semantics
                \\  Object.defineProperty(globalThis.console, Symbol.toStringTag, {
                \\    value: "console",
                \\    writable: false,
                \\    enumerable: false,
                \\    configurable: true
                \\  });
                \\})();
            ;
            _ = self.evaluateScript(console_script) catch |err| {
                std.debug.print("Warning: Failed to register console: {}\n", .{err});
            };
        }

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
            // Window context: full window, self, document, navigator, location, etc.
            // Per WebIDL spec, these are accessor properties that validate 'this'
            \\// Create __internal object to store singleton values
            \\// The accessor properties read from __internal to return the same object each time
            \\globalThis.__internal = {
            \\  isSecureContext: false,
            \\};
            \\
            \\// Helper function to check 'this' value for accessor properties
            \\// Per WebIDL spec, getters must validate that 'this' is the global object
            \\function __checkGlobalThis(thisArg, propName) {
            \\  if (thisArg === null || thisArg === undefined) {
            \\    return globalThis;
            \\  }
            \\  if (thisArg === globalThis) {
            \\    return globalThis;
            \\  }
            \\  throw new TypeError("'" + propName + "' called on an object that does not implement interface Window.");
            \\}
            \\globalThis.__checkGlobalThis = __checkGlobalThis;
            \\
            \\// Define window as an accessor property per WebIDL
            \\Object.defineProperty(globalThis, 'window', {
            \\  get: function() { return __checkGlobalThis(this, 'window'); },
            \\  enumerable: true, configurable: false
            \\});
            \\
            \\// Define self as an accessor property per WebIDL
            \\Object.defineProperty(globalThis, 'self', {
            \\  get: function() { return __checkGlobalThis(this, 'self'); },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Define document as an accessor property that reads from __internal
            \\Object.defineProperty(globalThis, 'document', {
            \\  get: function() {
            \\    __checkGlobalThis(this, 'document');
            \\    return globalThis.__internal.document;
            \\  },
            \\  enumerable: true, configurable: false
            \\});
            \\
            \\// Define navigator as an accessor property that reads from __internal
            \\Object.defineProperty(globalThis, 'navigator', {
            \\  get: function() {
            \\    __checkGlobalThis(this, 'navigator');
            \\    return globalThis.__internal.navigator;
            \\  },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Define location as an accessor property that reads from __internal
            \\Object.defineProperty(globalThis, 'location', {
            \\  get: function() {
            \\    __checkGlobalThis(this, 'location');
            \\    return globalThis.__internal.location;
            \\  },
            \\  set: function(value) {
            \\    __checkGlobalThis(this, 'location');
            \\    if (globalThis.__internal.location) {
            \\      globalThis.__internal.location.href = String(value);
            \\    }
            \\  },
            \\  enumerable: true, configurable: false
            \\});
            \\
            \\// Define history as an accessor property that reads from __internal
            \\Object.defineProperty(globalThis, 'history', {
            \\  get: function() {
            \\    __checkGlobalThis(this, 'history');
            \\    return globalThis.__internal.history;
            \\  },
            \\  enumerable: true, configurable: false
            \\});
            \\
            \\// Define performance as an accessor property that reads from __internal
            \\Object.defineProperty(globalThis, 'performance', {
            \\  get: function() {
            \\    __checkGlobalThis(this, 'performance');
            \\    return globalThis.__internal.performance;
            \\  },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Define isSecureContext as an accessor property
            \\Object.defineProperty(globalThis, 'isSecureContext', {
            \\  get: function() {
            \\    __checkGlobalThis(this, 'isSecureContext');
            \\    return globalThis.__internal.isSecureContext;
            \\  },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Simple property assignments for frame-related globals
            \\globalThis.parent = globalThis;
            \\globalThis.top = globalThis;
            \\globalThis.opener = null;
            \\globalThis.frames = globalThis;
            \\globalThis.length = 0;
            \\
            \\// Set up GLOBAL object for WPT tests - WINDOW context
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return true; },
            \\  isWorker: function() { return false; },
            \\  isShadowRealm: function() { return false; },
            \\};
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

    /// Load page content (fetch, parse, execute)
    ///
    /// Navigation flow per HTML Standard:
    /// 1. Fetch URL content
    /// 2. Parse HTML into DOM tree
    /// 3. Execute inline scripts (in document order)
    /// 4. Fire DOMContentLoaded event
    /// 5. Fire load event
    pub fn loadPage(self: *Context) !void {
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        // Step 1: Fetch URL content
        var result = navigation.fetchUrl(self.allocator, self.url, .{}) catch |err| {
            // Handle navigation errors gracefully
            std.debug.print("Navigation error for {s}: {}\n", .{ self.url, err });

            // For about:blank or errors, just return with empty document
            if (std.mem.eql(u8, self.url, "about:blank")) {
                return;
            }
            return error.NavigationFailed;
        };
        defer result.deinit();

        // Step 2: Check if HTML content
        const is_html = std.mem.indexOf(u8, result.content_type, "text/html") != null or
            std.mem.indexOf(u8, result.content_type, "application/xhtml") != null;

        if (!is_html) {
            // For non-HTML content, just set document.body.innerText
            // This is a simplified approach for now
            std.debug.print("Non-HTML content type: {s}\n", .{result.content_type});
            return;
        }

        // Step 3: Parse HTML (for script extraction)
        // Note: We're using a simplified approach here - just extracting scripts
        // and executing them. Full DOM tree construction would integrate with
        // the WebIDL Document interface.
        try self.executeInlineScripts(result.body);

        // Step 4: Fire DOMContentLoaded
        navigation.fireDOMContentLoaded(isolate, v8_ctx);

        // Step 5: Fire load event
        navigation.fireLoad(isolate, v8_ctx);
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

        // Get runtime context for HTMLParser
        const runtime_ctx = context_manager.getOrCreate(v8_ctx, self.allocator) catch |err| {
            std.debug.print("Failed to get runtime context: {}\n", .{err});
            return error.NotInitialized;
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

        // Update location object if it exists
        if (self.location_instance) |loc| {
            impls.Location.setHref(loc, url) catch |err| {
                std.debug.print("Warning: Failed to update location href: {}\n", .{err});
            };
        }
    }

    /// Evaluate JavaScript in this context
    pub fn evaluateScript(self: *Context, script: []const u8) !?*v8.ffi.Value {
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        // Create V8 string from content
        const source_str = v8.ffi.v8_String_NewFromUtf8(isolate, script.ptr, @intCast(script.len)) orelse return error.StringCreateFailed;

        // Compile script
        const compiled = v8.ffi.v8_Script_Compile(v8_ctx, source_str) orelse {
            const exception = v8.ffi.v8_TryCatch_Exception(v8_ctx);
            if (exception) |exc| {
                const exc_str = v8.ffi.v8_Value_ToString(exc, v8_ctx);
                if (exc_str) |str| {
                    const len = v8.ffi.v8_String_Utf8Length(str);
                    const buffer = try self.allocator.alloc(u8, @intCast(len));
                    defer self.allocator.free(buffer);
                    _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
                    std.debug.print("Script compile error: {s}\n", .{buffer});
                }
            }
            return error.CompileError;
        };

        // Run script
        const result = v8.ffi.v8_Script_Run(v8_ctx, compiled) orelse {
            const exception = v8.ffi.v8_TryCatch_Exception(v8_ctx);
            if (exception) |exc| {
                const exc_str = v8.ffi.v8_Value_ToString(exc, v8_ctx);
                if (exc_str) |str| {
                    const len = v8.ffi.v8_String_Utf8Length(str);
                    const buffer = try self.allocator.alloc(u8, @intCast(len));
                    defer self.allocator.free(buffer);
                    _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
                    std.debug.print("Script runtime error: {s}\n", .{buffer});
                }
            }
            return error.RuntimeError;
        };

        // Run microtasks
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

        return result;
    }

    /// Deinitialize the context
    pub fn deinit(self: *Context) void {
        // Clear timer interface and cancel all pending timers
        // This must happen before context manager deinit to prevent callbacks
        // from firing after the V8 context is disposed
        clearTimerInterface();

        // Cleanup context manager
        if (self.v8_context) |ctx| {
            context_manager.deinit();

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

    const allocator = current_allocator orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Create typed timer context wrapper (one-shot timer)
    const timer_wrapper = createV8TimerContext(allocator, isolate, callback_value, false) catch {
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

    // Create typed timer context wrapper (interval timer)
    const timer_wrapper = createV8TimerContext(allocator, isolate, callback_value, true) catch {
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

fn addEventListenerCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    if (v8.ffi.v8_Undefined(isolate)) |undef| {
        info.setReturnValue(undef);
    }
}

fn removeEventListenerCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    if (v8.ffi.v8_Undefined(isolate)) |undef| {
        info.setReturnValue(undef);
    }
}

fn dispatchEventCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
        info.setReturnValue(result);
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

/// fetch callback - stub implementation that throws TypeError
/// Full implementation requires HTTP client integration
fn fetchCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Throw TypeError indicating fetch is not implemented
    const error_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "fetch is not yet implemented", 28) orelse {
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
