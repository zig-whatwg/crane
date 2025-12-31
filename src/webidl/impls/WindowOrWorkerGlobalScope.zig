//! Implementation for WindowOrWorkerGlobalScope interface
//!
//! This mixin provides common functionality shared between Window and Worker global scopes.
//! The fetch() method implemented here can be used by any global scope that includes
//! this mixin.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const WindowOrWorkerGlobalScope = interfaces.WindowOrWorkerGlobalScope;

// V8 engine for timer callback invocation
const v8_engine = @import("v8");

// Fetch API support
const fetch_api = @import("fetch");
const global_fetch = fetch_api.webidl.global_fetch;
const ResponseImpl = @import("Response.zig");

// Async network support
const network = fetch_api.network;
const AsyncCurlManager = network.AsyncCurlManager;
const NetworkRequest = network.NetworkRequest;
const AsyncResult = network.AsyncResult;

// Body extraction support
const BlobImpl = @import("Blob.zig");
const URLSearchParamsImpl = @import("URLSearchParams.zig");

// Form serialization for URLSearchParams body
const form_serializer = @import("form_serializer");

// Environment settings for origin access
const environment_settings = runtime.environment_settings;
const Origin = environment_settings.Origin;

pub const State = WindowOrWorkerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
};

// ============================================================================
// Timer Support for setTimeout/setInterval
// ============================================================================

/// Context for JavaScript timer callbacks.
/// Stores the V8 function handle and arguments to invoke when timer fires.
const TimerCallbackContext = struct {
    /// Global handle to the JavaScript function (prevents GC)
    function_handle: *v8_engine.ffi.Value,
    /// V8 context pointer for invoking the function
    v8_context: *v8_engine.ffi.Context,
    /// V8 isolate pointer
    v8_isolate: *v8_engine.ffi.Isolate,
    /// Allocator for cleanup
    allocator: std.mem.Allocator,
    /// Timer ID for registry lookup
    timer_id: i32,
    /// Stored arguments to pass to the callback
    arguments: []runtime.JSValue,
    /// Is this a repeating timer (setInterval) or one-shot (setTimeout)?
    is_interval: bool,
    /// Interval duration in ms (for setInterval)
    interval_ms: u64,
    /// Reference to timer registry for cleanup
    registry: *TimerRegistry,

    const Self = @This();

    fn deinit(self: *Self) void {
        // Dispose the global handle to allow V8 GC
        v8_engine.ffi.v8_Global_Dispose(self.function_handle);

        // Free stored arguments
        if (self.arguments.len > 0) {
            self.allocator.free(self.arguments);
        }

        // Free the context itself
        self.allocator.destroy(self);
    }
};

/// Registry for active timers.
/// Stores timer contexts indexed by timer ID for clearTimeout/clearInterval.
const TimerRegistry = struct {
    timers: std.AutoHashMap(i32, *TimerCallbackContext),
    next_id: i32,
    allocator: std.mem.Allocator,

    const Self = @This();

    fn init(allocator: std.mem.Allocator) Self {
        return .{
            .timers = std.AutoHashMap(i32, *TimerCallbackContext).init(allocator),
            .next_id = 1,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        // Clean up all remaining timer contexts
        var it = self.timers.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.timers.deinit();
    }

    fn register(self: *Self, ctx: *TimerCallbackContext) i32 {
        const id = self.next_id;
        self.next_id += 1;
        ctx.timer_id = id;
        self.timers.put(id, ctx) catch return 0;
        return id;
    }

    fn unregister(self: *Self, id: i32) ?*TimerCallbackContext {
        return self.timers.fetchRemove(id).?.value;
    }

    fn get(self: *Self, id: i32) ?*TimerCallbackContext {
        return self.timers.get(id);
    }
};

/// Global timer registry (per-isolate in production, but global for now)
/// TODO: Move this to per-context state
var global_timer_registry: ?TimerRegistry = null;

fn getOrCreateTimerRegistry(allocator: std.mem.Allocator) *TimerRegistry {
    if (global_timer_registry == null) {
        global_timer_registry = TimerRegistry.init(allocator);
    }
    return &global_timer_registry.?;
}

/// Trampoline callback invoked by the timer manager.
/// Extracts the TimerCallbackContext and invokes the stored V8 function.
fn timerTrampoline(user_data: ?*anyopaque) void {
    const ctx: *TimerCallbackContext = @ptrCast(@alignCast(user_data orelse return));

    // Get the isolate and context
    const isolate = ctx.v8_isolate;
    const v8_context = ctx.v8_context;

    // Ensure we're in the correct isolate
    const current_isolate = v8_engine.ffi.v8_Isolate_GetCurrent();
    const need_enter_isolate = (current_isolate == null) or (current_isolate != isolate);
    if (need_enter_isolate) {
        v8_engine.ffi.v8_Isolate_Enter(isolate);
    }
    defer if (need_enter_isolate) {
        v8_engine.ffi.v8_Isolate_Exit(isolate);
    };

    // Create HandleScope for V8 handle allocation
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(isolate);
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Enter context if needed
    const current_context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate);
    const need_enter_context = (current_context == null) or (current_context != v8_context);
    if (need_enter_context) {
        v8_engine.ffi.v8_Context_Enter(v8_context);
    }
    defer if (need_enter_context) {
        v8_engine.ffi.v8_Context_Exit(v8_context);
    };

    // Get the function from the global handle
    const function = v8_engine.ffi.v8_Global_Get(isolate, ctx.function_handle) orelse {
        // Function was garbage collected - clean up
        _ = ctx.registry.unregister(ctx.timer_id);
        ctx.deinit();
        return;
    };

    // Prepare arguments
    const undefined_recv = v8_engine.ffi.v8_Undefined(isolate);

    // Convert runtime.JSValue arguments to V8 values
    var args: [16]*v8_engine.ffi.Value = undefined;
    var arg_count: c_int = 0;

    for (ctx.arguments) |arg| {
        if (arg_count >= 16) break;
        if (arg.toAnyopaque()) |ptr| {
            args[@intCast(arg_count)] = @ptrCast(ptr);
            arg_count += 1;
        }
    }

    // Call the function
    _ = v8_engine.ffi.v8_Function_Call(
        @ptrCast(function),
        v8_context,
        @ptrCast(undefined_recv),
        arg_count,
        if (arg_count > 0) &args else null,
    );

    // For one-shot timers (setTimeout), clean up after invocation
    if (!ctx.is_interval) {
        // Remove from registry and clean up
        _ = ctx.registry.unregister(ctx.timer_id);
        ctx.deinit();
    }
    // For interval timers, the timer manager handles rescheduling
    // The LibuvTimerManager's setInterval mechanism or the platform's
    // timer backend handles repeated invocation
}

// ============================================================================
// CORS Support - Origin Detection
// ============================================================================

/// Extract origin from a URL string (scheme://host:port)
/// Returns null if URL is malformed.
fn extractOrigin(url: []const u8) ?[]const u8 {
    // Find scheme separator
    const scheme_end = std.mem.indexOf(u8, url, "://") orelse return null;

    // Find path start (after host)
    const after_scheme = url[scheme_end + 3 ..];
    const path_start = std.mem.indexOf(u8, after_scheme, "/");

    if (path_start) |ps| {
        return url[0 .. scheme_end + 3 + ps];
    } else {
        return url;
    }
}

/// Check if a request URL is cross-origin relative to the document's origin.
/// Cross-origin means different scheme, host, or port.
fn isCrossOrigin(document_origin: ?[]const u8, request_url: []const u8) bool {
    const doc_origin = document_origin orelse return true;
    const req_origin = extractOrigin(request_url) orelse return true;

    return !std.mem.eql(u8, doc_origin, req_origin);
}

/// Get the document's origin string from the context.
/// Returns null if origin cannot be determined.
fn getDocumentOrigin(ctx: runtime.Context, allocator: std.mem.Allocator) ?[]const u8 {
    _ = ctx;
    _ = allocator;
    // TODO: Implement proper origin extraction from environment settings
    // For now, return null - cross-origin detection will be skipped
    // This is acceptable for initial implementation as the Origin header
    // will fall back to the request URL origin
    return null;
}

// ============================================================================
// Async Fetch Support
// ============================================================================

/// Context for async fetch completion callback.
/// Holds the V8 promise handle and engine context needed to resolve/reject.
const FetchCompletionContext = struct {
    /// Promise handle to resolve/reject
    promise_handle: *anyopaque,
    /// Allocator for cleanup
    allocator: std.mem.Allocator,
    /// Engine interface for V8 operations
    engine: *const runtime.EngineInterface,
    /// Engine context (V8 context pointer)
    engine_ctx: *anyopaque,
    /// Runtime context for creating Response instance
    runtime_ctx: runtime.Context,

    fn deinit(self: *FetchCompletionContext) void {
        // Destroy promise handle
        if (self.engine.destroyPromiseHandle) |destroy| {
            destroy(self.promise_handle, self.allocator);
        }
        self.allocator.destroy(self);
    }
};

/// Abort signal check callback for in-flight fetch cancellation.
/// Called periodically during curl data transfer to check if AbortSignal has been aborted.
/// This enables AbortSignal.timeout() and manual abort() to cancel in-progress HTTP requests.
fn abortSignalCheck(user_data: ?*anyopaque) bool {
    const signal: *runtime.Instance = @ptrCast(@alignCast(user_data orelse return false));
    const AbortSignalImpl = @import("AbortSignal.zig");
    return AbortSignalImpl.get_aborted(signal) catch false;
}

/// Completion callback invoked when async fetch completes.
/// This runs on the event loop thread when the HTTP response arrives.
fn asyncFetchCompletionCallback(result: AsyncResult, user_data: ?*anyopaque) void {
    const ctx: *FetchCompletionContext = @ptrCast(@alignCast(user_data orelse return));

    switch (result) {
        .success => |response| {
            // Create a WebIDL Response instance wrapping the NetworkResponse
            const response_instance = ResponseImpl.initWithNetworkResponse(
                ctx.allocator,
                ctx.runtime_ctx,
                response,
            ) catch |err| {
                // Failed to create Response object - reject Promise
                ctx.engine.rejectPromise(ctx.engine_ctx, ctx.promise_handle, err) catch {};
                ctx.deinit();
                return;
            };

            // Wrap the Response instance as a V8 object
            const wrapInstance = ctx.engine.wrapInstance orelse {
                ctx.engine.rejectPromise(ctx.engine_ctx, ctx.promise_handle, error.InvalidState) catch {};
                ctx.deinit();
                return;
            };

            const js_response = wrapInstance(ctx.engine_ctx, response_instance) catch {
                ctx.engine.rejectPromise(ctx.engine_ctx, ctx.promise_handle, error.InvalidState) catch {};
                ctx.deinit();
                return;
            };

            // Resolve the promise with the JS Response object
            ctx.engine.resolvePromise(ctx.engine_ctx, ctx.promise_handle, js_response) catch {};
        },
        .failure => |net_error| {
            // Map network error to fetch error per WHATWG Fetch spec
            // Spec: https://fetch.spec.whatwg.org/#concept-network-error
            const fetch_error: anyerror = switch (net_error) {
                // AbortError: fetch was aborted by user/signal
                error.Aborted => error.AbortError,
                // NetworkError: general network failures (connection, DNS, TLS)
                error.ConnectionRefused, error.ConnectionReset, error.ConnectionTimeout => error.NetworkError,
                error.DnsResolutionFailed, error.HostUnreachable, error.NetworkUnreachable => error.NetworkError,
                error.RequestTimeout => error.NetworkError,
                error.SslCertificateError, error.SslHandshakeFailed => error.NetworkError,
                error.TooManyRedirects => error.NetworkError,
                // TypeError: malformed URL (spec says reject with TypeError for bad URLs)
                error.InvalidUrl => error.TypeError,
                // ProtocolError: could be config issue (bad params) or protocol mismatch
                // Map to NetworkError since it's a network-level issue
                error.ProtocolError => error.NetworkError,
                // OutOfMemory: propagate as-is
                error.OutOfMemory => error.OutOfMemory,
                // Unknown: catch-all for unexpected errors
                error.Unknown => error.NetworkError,
            };
            ctx.engine.rejectPromise(ctx.engine_ctx, ctx.promise_handle, fetch_error) catch {};
        },
    }

    ctx.deinit();
}

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for origin
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for isSecureContext
pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crossOriginIsolated
pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for indexedDB
pub fn get_indexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for trustedTypes
pub fn get_trustedTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for performance
pub fn get_performance(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for caches
pub fn get_caches(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scheduler
pub fn get_scheduler(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crypto
pub fn get_crypto(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: reportError
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#dom-reporterror
///
/// Reports an exception to the console and fires an ErrorEvent.
/// This is the programmatic way for scripts to report exceptions.
///
/// The algorithm is:
/// 1. If e is not an exception, convert it to one
/// 2. Get error message, filename, line, column from exception
/// 3. Fire "error" event at the global object
/// 4. If not canceled, report to console
pub fn call_reportError(instance: *runtime.Instance, e: runtime.JSValue) anyerror!void {
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse {
        return error.InvalidStateError;
    };

    const v8_context: *v8_engine.ffi.Context = instance.ctx.getEngineContextAs(v8_engine.ffi.Context) orelse {
        return error.InvalidStateError;
    };

    // Create HandleScope
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(isolate);
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Get the error value (may be any JS value, but we treat it as an error)
    const error_value: ?*anyopaque = e.toAnyopaque();

    // TODO: Extract actual message, filename, lineno, colno from Error stack trace
    // For now, use generic error info. Full implementation would:
    // 1. Check if e is an Error object
    // 2. Get e.message, e.fileName, e.lineNumber, e.columnNumber
    // 3. Parse stack trace for location info
    _ = v8_context; // Will be used for property access in full implementation
    const message: []const u8 = "Uncaught error";
    const filename: []const u8 = "";
    const lineno: u32 = 0;
    const colno: u32 = 0;

    // Import ErrorEvent implementation
    const ErrorEventImpl = @import("ErrorEvent.zig");

    // Create ErrorEvent
    const error_event = try ErrorEventImpl.createErrorEvent(
        instance.ctx.allocator,
        instance.ctx,
        message,
        filename,
        lineno,
        colno,
        error_value,
        true, // cancelable
    );

    // Set isTrusted (reportError fires a trusted event)
    {
        var ev_state = error_event.getState(interfaces.ErrorEvent.State);
        ev_state.base.own.isTrusted = true;
        ev_state.base.own.target = instance;
        ev_state.base.own.currentTarget = instance;
    }

    // Dispatch via EventTarget.dispatchEvent
    const EventTarget = interfaces.EventTarget;
    const not_canceled = try EventTarget.call_dispatchEvent(instance, error_event);

    // If not canceled, report to console
    if (not_canceled) {
        std.log.warn("Uncaught (in reportError): {s}", .{message});
    }
}

/// Operation: setInterval
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-setinterval
///
/// Schedules a callback to be invoked repeatedly at a specified interval.
/// The handler can be a JavaScript function or a string (eval'd code).
///
/// ## Implementation Notes
///
/// Similar to setTimeout, but the callback is invoked repeatedly until
/// clearInterval is called with the returned timer ID.
pub fn call_setInterval(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    const allocator = instance.ctx.allocator;

    // Get timeout value (default 0, minimum 4ms per spec for intervals)
    const timeout_ms: u64 = if (timeout.wasPassed())
        @intCast(@max(4, timeout.getValue())) // Minimum 4ms for intervals per spec
    else
        4;

    switch (handler) {
        .function => |fn_ptr| {
            // The function pointer is actually a tagged GlobalHandle pointer.
            const untagged = v8_engine.pointer_tag.untagPointer(@ptrCast(fn_ptr));

            if (untagged.tag != .global_handle and untagged.tag != .untagged) {
                return error.TypeError;
            }

            const function_handle: *v8_engine.ffi.Value = @ptrCast(@alignCast(untagged.ptr));

            // Get isolate and context
            const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.InvalidStateError;
            const v8_context: *v8_engine.ffi.Context = instance.ctx.getEngineContextAs(v8_engine.ffi.Context) orelse return error.InvalidStateError;

            // Verify the handle points to a function
            const local_value = v8_engine.ffi.v8_Global_Get(isolate, function_handle) orelse return error.InvalidStateError;
            if (!v8_engine.ffi.v8_Value_IsFunction(@ptrCast(local_value))) {
                return error.TypeError;
            }

            // Create timer callback context
            const timer_ctx = try allocator.create(TimerCallbackContext);
            errdefer allocator.destroy(timer_ctx);

            // Create a new GlobalHandle from the handle
            const global_copy = v8_engine.ffi.v8_Value_ToGlobal(isolate, @ptrCast(local_value)) orelse return error.OutOfMemory;

            // Copy arguments
            const args_copy = if (arguments.len > 0)
                try allocator.dupe(runtime.JSValue, arguments)
            else
                &[_]runtime.JSValue{};

            // Get or create timer registry
            const registry = getOrCreateTimerRegistry(allocator);

            timer_ctx.* = .{
                .function_handle = global_copy,
                .v8_context = v8_context,
                .v8_isolate = isolate,
                .allocator = allocator,
                .timer_id = 0,
                .arguments = args_copy,
                .is_interval = true, // This is an interval timer
                .interval_ms = timeout_ms,
                .registry = registry,
            };

            // Register the timer
            const timer_id = registry.register(timer_ctx);
            if (timer_id == 0) {
                timer_ctx.deinit();
                return error.OutOfMemory;
            }

            // Schedule the timer via the platform timer interface
            if (instance.ctx.getTimer()) |timer_interface| {
                // For intervals, we need to set up a repeating timer
                // The timerTrampoline handles rescheduling for intervals
                _ = timer_interface.setTimeout(timeout_ms, timerTrampoline, timer_ctx);
            } else |_| {
                _ = registry.unregister(timer_id);
                timer_ctx.deinit();
                return error.InvalidStateError;
            }

            return timer_id;
        },
        .domstring => |_| {
            // String handlers (eval) - legacy feature, security risk
            return 0;
        },
        .trusted_script => |_| {
            return error.NotImplemented;
        },
    }
}

/// Operation: atob
pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.ByteString {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: btoa
pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.DOMString {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: createImageBitmap
pub fn call_createImageBitmap(instance: *runtime.Instance, image: typedefs.ImageBitmapSource, options: webidl.Opt(dictionaries.ImageBitmapOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = image;
    _ = options;
    return error.NotImplemented;
}

/// Operation: clearInterval
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-clearinterval
///
/// Cancels a previously scheduled setInterval callback.
pub fn call_clearInterval(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    if (!id.wasPassed()) return;

    const timer_id = id.getValue();
    if (timer_id <= 0) return;

    // Get the timer registry
    const registry = getOrCreateTimerRegistry(instance.ctx.allocator);

    // Unregister and clean up
    if (registry.unregister(timer_id)) |ctx| {
        // Get timer interface to cancel the timer
        if (instance.ctx.getTimer()) |timer_interface| {
            timer_interface.clearTimeout(@intCast(timer_id));
        } else |_| {}

        // Clean up the context
        ctx.deinit();
    }
}

/// Operation: queueMicrotask
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-queuemicrotask
///
/// Queues a microtask to invoke the given callback.
/// Microtasks execute after the current task completes but before the next task begins.
///
/// Implementation:
/// 1. Create Global handle for the VoidFunction callback
/// 2. Queue in V8's microtask queue
/// 3. Dispose Global handle after callback executes
pub fn call_queueMicrotask(instance: *runtime.Instance, callback: callbacks.VoidFunction) anyerror!void {
    const allocator = instance.ctx.allocator;

    // The callback is a tagged pointer containing a V8 GlobalHandle
    // Untag to get the raw pointer
    const untagged = v8_engine.pointer_tag.untagPointer(callback);

    if (untagged.tag != .global_handle and untagged.tag != .untagged) {
        // Not a valid function pointer
        std.log.warn("queueMicrotask: callback is not a valid function (tag={})", .{untagged.tag});
        return error.InvalidCallback;
    }

    // Get V8 isolate and context
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse {
        std.log.warn("queueMicrotask: no current V8 isolate", .{});
        return error.NoIsolate;
    };

    const v8_context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        std.log.warn("queueMicrotask: no current V8 context", .{});
        return error.NoContext;
    };

    // Allocate context for the microtask callback
    const ctx = try allocator.create(MicrotaskCallbackContext);
    errdefer allocator.destroy(ctx);

    // Get the function handle from the global handle
    const global_handle = v8_engine.GlobalHandle{ .ptr = @ptrCast(@alignCast(untagged.ptr)) };
    const local_value = global_handle.get(isolate) orelse {
        std.log.warn("queueMicrotask: failed to get local value from global handle", .{});
        return error.InvalidCallback;
    };

    // Verify it's a function
    if (!v8_engine.ffi.v8_Value_IsFunction(@ptrCast(local_value))) {
        std.log.warn("queueMicrotask: callback is not a function", .{});
        return error.InvalidCallback;
    }

    // Create a new global handle for the callback (to prevent GC)
    const function_global = v8_engine.ffi.v8_Global_New(isolate, @ptrCast(local_value)) orelse {
        return error.OutOfMemory;
    };

    ctx.* = .{
        .function_handle = function_global,
        .v8_context = v8_context,
        .v8_isolate = isolate,
        .allocator = allocator,
    };

    // Enqueue the microtask via V8
    const callback_ptr: ?*const anyopaque = @ptrCast(&microtaskTrampoline);
    v8_engine.ffi.v8_Isolate_EnqueueMicrotask(isolate, callback_ptr, ctx);
}

/// Context for microtask callbacks
const MicrotaskCallbackContext = struct {
    /// Global handle to the JavaScript function (prevents GC)
    function_handle: *v8_engine.ffi.Value,
    /// V8 context pointer for invoking the function
    v8_context: *v8_engine.ffi.Context,
    /// V8 isolate pointer
    v8_isolate: *v8_engine.ffi.Isolate,
    /// Allocator for cleanup
    allocator: std.mem.Allocator,
};

/// Trampoline function for microtask execution
/// Called by V8 when the microtask is due to run
fn microtaskTrampoline(data: ?*anyopaque) callconv(.C) void {
    const ctx: *MicrotaskCallbackContext = @ptrCast(@alignCast(data orelse return));
    defer {
        // Dispose the global handle and free the context
        v8_engine.ffi.v8_Global_Dispose(ctx.function_handle);
        ctx.allocator.destroy(ctx);
    }

    // Get the local handle from the global
    const local_value = v8_engine.ffi.v8_Global_Get(ctx.v8_isolate, ctx.function_handle) orelse {
        std.log.warn("microtaskTrampoline: failed to get local value", .{});
        return;
    };

    // Cast to function
    const function: *v8_engine.ffi.Function = @ptrCast(local_value);

    // Call the function with no arguments
    const undefined_recv = v8_engine.ffi.v8_Undefined(ctx.v8_isolate);
    _ = v8_engine.ffi.v8_Function_Call(function, ctx.v8_context, @ptrCast(undefined_recv), 0, null);
}

/// Operation: structuredClone
pub fn call_structuredClone(instance: *runtime.Instance, value: runtime.JSValue, options: webidl.Opt(dictionaries.StructuredSerializeOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = value;
    _ = options;
    return error.NotImplemented;
}

/// Operation: setTimeout
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-settimeout
///
/// Schedules a callback to be invoked after a specified delay.
/// The handler can be a JavaScript function or a string (eval'd code).
///
/// ## Implementation Notes
///
/// The `TimerHandler.function` variant is actually a tagged GlobalHandle pointer.
/// The V8 binding layer creates a GlobalHandle for function arguments and returns
/// the pointer tagged with `.global_handle`. We extract this and use it to invoke
/// the callback when the timer fires.
///
/// ## Timer Infrastructure
///
/// - TimerCallbackContext: Stores function handle, context, arguments
/// - TimerRegistry: Tracks active timers by ID
/// - timerTrampoline: Invokes V8 function when timer fires
/// - LibuvTimerManager: Schedules timers via libuv (or platform timer backend)
pub fn call_setTimeout(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    const allocator = instance.ctx.allocator;

    // Get timeout value (default 0)
    const timeout_ms: u64 = if (timeout.wasPassed())
        @intCast(@max(0, timeout.getValue()))
    else
        0;

    switch (handler) {
        .function => |fn_ptr| {
            // The function pointer is actually a tagged GlobalHandle pointer.
            // The V8 binding layer creates a GlobalHandle for function arguments
            // and returns the pointer tagged with `.global_handle`.
            //
            // See: src/runtime/engines/v8/conversions.zig line ~1150
            // See: src/runtime/engines/v8/pointer_tag.zig for tagging details

            // Untag the pointer to get the raw GlobalHandle
            const untagged = v8_engine.pointer_tag.untagPointer(@ptrCast(fn_ptr));

            // Verify it's a GlobalHandle
            if (untagged.tag != .global_handle and untagged.tag != .untagged) {
                // Not a GlobalHandle - this shouldn't happen for function callbacks
                return error.TypeError;
            }

            // Get the V8 function pointer
            const function_handle: *v8_engine.ffi.Value = @ptrCast(@alignCast(untagged.ptr));

            // Get isolate and context
            const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.InvalidStateError;
            const v8_context: *v8_engine.ffi.Context = instance.ctx.getEngineContextAs(v8_engine.ffi.Context) orelse return error.InvalidStateError;

            // Verify the handle points to a function
            // For GlobalHandles, we need to get the Local first
            const local_value = v8_engine.ffi.v8_Global_Get(isolate, function_handle) orelse return error.InvalidStateError;
            if (!v8_engine.ffi.v8_Value_IsFunction(@ptrCast(local_value))) {
                return error.TypeError;
            }

            // Create timer callback context
            const timer_ctx = try allocator.create(TimerCallbackContext);
            errdefer allocator.destroy(timer_ctx);

            // Create a new GlobalHandle from the handle (we need our own copy)
            // The original GlobalHandle may be disposed by the caller
            const global_copy = v8_engine.ffi.v8_Value_ToGlobal(isolate, @ptrCast(local_value)) orelse return error.OutOfMemory;

            // Copy arguments
            const args_copy = if (arguments.len > 0)
                try allocator.dupe(runtime.JSValue, arguments)
            else
                &[_]runtime.JSValue{};

            // Get or create timer registry
            const registry = getOrCreateTimerRegistry(allocator);

            timer_ctx.* = .{
                .function_handle = global_copy,
                .v8_context = v8_context,
                .v8_isolate = isolate,
                .allocator = allocator,
                .timer_id = 0, // Will be set by registry
                .arguments = args_copy,
                .is_interval = false,
                .interval_ms = 0,
                .registry = registry,
            };

            // Register the timer
            const timer_id = registry.register(timer_ctx);
            if (timer_id == 0) {
                timer_ctx.deinit();
                return error.OutOfMemory;
            }

            // Schedule the timer via the platform timer interface
            if (instance.ctx.getTimer()) |timer_interface| {
                _ = timer_interface.setTimeout(timeout_ms, timerTrampoline, timer_ctx);
            } else |_| {
                // No timer interface available - clean up and fail
                _ = registry.unregister(timer_id);
                timer_ctx.deinit();
                return error.InvalidStateError;
            }

            return timer_id;
        },
        .domstring => |_| {
            // String handlers (eval) - legacy feature, security risk
            // Per spec, string handlers are deprecated. Return 0 (noop timer).
            return 0;
        },
        .trusted_script => |_| {
            // TrustedScript handlers - not yet implemented
            // This would require Trusted Types integration
            return error.NotImplemented;
        },
    }
}

/// Operation: clearTimeout
/// Cancels a previously scheduled setTimeout callback.
pub fn call_clearTimeout(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    if (!id.wasPassed()) return;

    const timer_id = id.getValue();
    if (timer_id <= 0) return;

    // Get the timer registry
    const registry = getOrCreateTimerRegistry(instance.ctx.allocator);

    // Unregister and clean up
    if (registry.unregister(timer_id)) |ctx| {
        // Get timer interface to cancel the timer
        if (instance.ctx.getTimer()) |timer_interface| {
            timer_interface.clearTimeout(@intCast(timer_id));
        } else |_| {}

        // Clean up the context
        ctx.deinit();
    }
}

/// Operation: fetch
/// Implements the global fetch() function per WHATWG Fetch Standard.
/// Spec: https://fetch.spec.whatwg.org/#fetch-method
///
/// This is the mixin implementation used by Window and WorkerGlobalScope.
/// Implementation notes:
/// - Extracts URL from RequestInfo (string or Request object)
/// - Applies RequestInit options (method, headers, body, mode, credentials, etc.)
/// - Returns a Promise that resolves to a Response object
/// - Per spec, fetch() ALWAYS returns a Promise (never throws synchronously)
/// - All errors during initialization are converted to Promise rejections
pub fn call_fetch(instance: *runtime.Instance, input: typedefs.RequestInfo, init_data: webidl.Opt(dictionaries.RequestInit)) anyerror!runtime.JSValue {
    const allocator = instance.ctx.allocator;

    // Per WHATWG Fetch spec, fetch() MUST always return a Promise.
    // We need to create the Promise FIRST, before any error-prone operations.
    // Get the engine interface and context - these are required for Promise creation.
    const engine = instance.ctx.engine orelse {
        // Fatal: no engine means we can't create a Promise at all.
        // This is a configuration error, not a fetch error.
        return error.InvalidStateError;
    };
    const engine_ctx = instance.ctx.engine_ctx orelse {
        return error.InvalidStateError;
    };

    // Create a Promise to return to JavaScript FIRST - before any other operations.
    // Per spec, all subsequent errors must reject this promise, not throw synchronously.
    const promise_handle = engine.createPromise(engine_ctx, allocator) catch {
        // If we can't even create a promise, we have a fatal error.
        return error.OutOfMemory;
    };

    // Call the internal implementation that handles all the fetch logic.
    // Any error from here will reject the promise instead of throwing.
    const result = callFetchInternal(instance, input, init_data, allocator, engine, engine_ctx, promise_handle);

    if (result) |maybe_async_value| {
        if (maybe_async_value) |async_promise_value| {
            // Async path: the promise is owned by the completion callback.
            // Return the promise directly without cleaning up the handle.
            return async_promise_value;
        } else {
            // Sync path: promise was already resolved/rejected, clean up handle.
            return getPromiseAndCleanup(engine, promise_handle, allocator);
        }
    } else |err| {
        // Error during initialization: reject the promise instead of throwing synchronously.
        engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
        return getPromiseAndCleanup(engine, promise_handle, allocator);
    }
}

/// Internal fetch implementation that can return errors.
/// All errors from this function are caught by call_fetch and converted to Promise rejections.
/// Returns:
/// - runtime.JSValue for async path (promise is owned by callback, return promise directly)
/// - null for sync path (promise was resolved/rejected, caller should clean up handle)
fn callFetchInternal(
    instance: *runtime.Instance,
    input: typedefs.RequestInfo,
    init_data: webidl.Opt(dictionaries.RequestInit),
    allocator: std.mem.Allocator,
    engine: *const runtime.EngineInterface,
    engine_ctx: *anyopaque,
    promise_handle: *anyopaque,
) !?runtime.JSValue {
    // Step 5 per Fetch spec: If request's signal's aborted flag is set, reject with AbortError
    // https://fetch.spec.whatwg.org/#fetch-method
    // Check abort signal BEFORE any other fetch work
    if (init_data.wasPassed()) {
        const init_opts = init_data.getValue();
        if (init_opts.signal) |signal| {
            // Import AbortSignal impl to check aborted state
            const AbortSignalImpl = @import("AbortSignal.zig");
            const aborted = AbortSignalImpl.get_aborted(signal) catch false;
            if (aborted) {
                // Signal is already aborted - reject promise with AbortError
                return error.AbortError;
            }
        }
    }

    // Create headers list for network request
    // These will be converted from HeadersInit and passed to NetworkRequest
    var headers_list: std.ArrayList(NetworkRequest.Header) = .{};
    defer headers_list.deinit(allocator);

    // Track the method string (default to GET)
    var request_method: []const u8 = "GET";

    // Extract URL from input (RequestInfo is USVString or Request)
    // Track if URL was allocated (from get_href) so we can free it later
    var url_allocated: bool = false;
    const url_str: []const u8 = switch (input) {
        .usvstring => |s| s,
        .request => |req_instance| blk: {
            // Check if this is actually a Request instance by trying to get its URL.
            // If the object is a URL or other stringifiable object incorrectly classified
            // as a Request (because it's a WebIDL interface), we need to convert it to string.
            //
            // First, try to get URL from Request instance
            if (interfaces.Request.get_url(req_instance)) |req_url| {
                break :blk req_url;
            } else |_| {
                // Not a valid Request - try to get URL from URL interface
                // The URL interface has a get_href method that returns the full URL string
                if (interfaces.URL.get_href(req_instance)) |url_href| {
                    url_allocated = true; // get_href allocates a new string
                    break :blk url_href;
                } else |_| {
                    // Neither Request nor URL - this is an error
                    return error.TypeError;
                }
            }
        },
    };
    // Ensure allocated URL is freed on all exit paths
    defer if (url_allocated) allocator.free(url_str);

    // Build RequestInit options for the internal fetch
    var request_init = fetch_api.webidl.request.RequestInit{};

    // Apply RequestInit options if provided
    if (init_data.wasPassed()) {
        const init_opts = init_data.getValue();

        // Method
        if (init_opts.method) |method| {
            request_init.method = method;
            request_method = method;
        }

        // Headers - convert from HeadersInit to internal format
        // HeadersInit can be sequence<sequence<ByteString>> or record<ByteString, ByteString>
        if (init_opts.headers) |headers_init| {
            switch (headers_init) {
                .sequence_byte_string_sequence => |seq| {
                    // Each inner sequence should have 2 elements: [name, value]
                    for (seq) |header_pair| {
                        if (header_pair.len >= 2) {
                            try headers_list.append(allocator, .{
                                .name = header_pair[0],
                                .value = header_pair[1],
                            });
                        }
                    }
                },
                .byte_string_byte_string_record => |record| {
                    // Record is a slice of key-value structs
                    for (record) |entry| {
                        try headers_list.append(allocator, .{
                            .name = entry.key,
                            .value = entry.value,
                        });
                    }
                },
            }
        }

        // Body - convert from BodyInit to internal format
        // Spec: https://fetch.spec.whatwg.org/#bodyinit-safely-extract
        //
        // Content-Type defaults per spec:
        // - USVString: text/plain;charset=UTF-8
        // - Blob: Blob's type (if non-empty)
        // - BufferSource: (none)
        // - URLSearchParams: application/x-www-form-urlencoded;charset=UTF-8
        // - FormData: multipart/form-data; boundary=...
        // - ReadableStream: (none)
        if (init_opts.body) |body_init| {
            switch (body_init) {
                .xmlhttp_request_body_init => |xhr_body| {
                    switch (xhr_body) {
                        .usvstring => |s| {
                            // USVString body: duplicate for async lifetime
                            const body_bytes = allocator.dupe(u8, s) catch null;
                            if (body_bytes) |b| {
                                request_init.body = b;
                                // Set Content-Type if not already present
                                if (!headersListContains(headers_list.items, "Content-Type")) {
                                    headers_list.append(allocator, .{
                                        .name = "Content-Type",
                                        .value = "text/plain;charset=UTF-8",
                                    }) catch {};
                                }
                            }
                        },
                        .blob => |blob_instance| {
                            // Extract bytes from Blob's internal state
                            if (BlobImpl.getInternal(blob_instance)) |internal| {
                                // Duplicate bytes for async lifetime safety
                                const body_bytes = allocator.dupe(u8, internal.blob_data.bytes) catch null;
                                if (body_bytes) |b| {
                                    request_init.body = b;
                                    // Set Content-Type from blob's type if non-empty and not already set
                                    const blob_type = internal.blob_data.getType();
                                    if (blob_type.len > 0 and !headersListContains(headers_list.items, "Content-Type")) {
                                        headers_list.append(allocator, .{
                                            .name = "Content-Type",
                                            .value = blob_type,
                                        }) catch {};
                                    }
                                }
                            }
                        },
                        .buffer_source => |buffer_source| {
                            // Extract bytes from BufferSource (ArrayBuffer or ArrayBufferView)
                            const bytes = buffer_source.asBytes() catch null;
                            if (bytes) |b| {
                                // Duplicate bytes for async lifetime safety
                                const body_bytes = allocator.dupe(u8, b) catch null;
                                if (body_bytes) |duped| {
                                    request_init.body = duped;
                                    // No default Content-Type for BufferSource per spec
                                }
                            }
                        },
                        .urlsearch_params => |usp_instance| {
                            // Serialize URLSearchParams to application/x-www-form-urlencoded
                            // serialize() returns an allocated string, so it's already owned
                            const serialized = URLSearchParamsImpl.serialize(usp_instance) catch null;
                            if (serialized) |s| {
                                request_init.body = s;
                                // Set Content-Type if not already present
                                if (!headersListContains(headers_list.items, "Content-Type")) {
                                    headers_list.append(allocator, .{
                                        .name = "Content-Type",
                                        .value = "application/x-www-form-urlencoded;charset=UTF-8",
                                    }) catch {};
                                }
                            }
                        },
                        .form_data => {
                            // FormData requires multipart/form-data encoding
                            // TODO: Implement multipart encoding when FormData impl is complete
                            // Content-Type should be "multipart/form-data; boundary=..."
                        },
                    }
                },
                .readable_stream => {
                    // ReadableStream body requires async streaming
                    // TODO: Implement streaming body when async I/O is complete (whatwg-ij93j)
                    // This is complex: need to read chunks as they arrive and send to network
                },
            }
        }

        // Note: mode, referrer, referrerPolicy are applied below during
        // NetworkRequest construction (mode affects CORS, referrer affects headers)
    }

    // Extract RequestInit options for network configuration
    // Spec: https://fetch.spec.whatwg.org/#request-class
    var follow_redirects: bool = true; // Default: follow redirects

    if (init_data.wasPassed()) {
        const init_opts = init_data.getValue();

        // Redirect mode - controls how redirects are handled
        // Spec: https://fetch.spec.whatwg.org/#dom-requestinit-redirect
        if (init_opts.redirect) |redirect| {
            follow_redirects = switch (redirect) {
                ._follow_ => true, // Follow redirects automatically
                ._error_ => false, // Will error on redirect (TODO: handle in completion callback)
                ._manual_ => false, // Return opaque-redirect response (TODO: handle in callback)
            };
        }

        // Cache mode - add appropriate Cache-Control headers
        // Spec: https://fetch.spec.whatwg.org/#dom-requestinit-cache
        if (init_opts.cache) |cache_mode| {
            switch (cache_mode) {
                ._no_store_ => {
                    // Don't store request/response in cache
                    try headers_list.append(allocator, .{
                        .name = "Cache-Control",
                        .value = "no-store",
                    });
                },
                ._no_cache_ => {
                    // Revalidate with server before using cached response
                    try headers_list.append(allocator, .{
                        .name = "Cache-Control",
                        .value = "no-cache",
                    });
                },
                ._reload_ => {
                    // Ignore cache, fetch fresh from server
                    try headers_list.append(allocator, .{
                        .name = "Cache-Control",
                        .value = "no-cache",
                    });
                    try headers_list.append(allocator, .{
                        .name = "Pragma",
                        .value = "no-cache",
                    });
                },
                ._force_cache_ => {
                    // Use cache even if stale, only fetch if not cached
                    // No special headers needed - let cache decide
                },
                ._only_if_cached_ => {
                    // Only use cache, fail if not cached
                    // Note: This requires mode to be "same-origin"
                    try headers_list.append(allocator, .{
                        .name = "Cache-Control",
                        .value = "only-if-cached",
                    });
                },
                ._default_ => {
                    // Normal cache behavior - no special headers
                },
            }
        }

        // Credentials mode - controls cookie behavior
        // Spec: https://fetch.spec.whatwg.org/#dom-requestinit-credentials
        // TODO: Configure curl to send/receive cookies based on:
        // - omit: Don't send or receive cookies
        // - same-origin: Only for same-origin requests (default)
        // - include: Always send cookies, even cross-origin
        if (init_opts.credentials) |credentials| {
            _ = credentials; // Will be used when cookie jar is implemented
        }
    }

    // CORS handling: Add Origin header for cross-origin requests
    // Per WHATWG Fetch spec, cross-origin requests must include the Origin header
    // This is required for WPT tests that use alternate ports (e.g., localhost:8000 → localhost:8002)
    const document_origin = getDocumentOrigin(instance.ctx, allocator);
    const is_cross_origin = isCrossOrigin(document_origin, url_str);

    if (is_cross_origin) {
        if (document_origin) |origin| {
            try headers_list.append(allocator, .{
                .name = "Origin",
                .value = origin,
            });
        } else {
            // If we can't determine the document origin, use the request URL's origin as a fallback
            // This handles cases where the context doesn't have an api_base_url set
            if (extractOrigin(url_str)) |req_origin| {
                try headers_list.append(allocator, .{
                    .name = "Origin",
                    .value = req_origin,
                });
            }
        }
    }

    // Try async path first (if network manager is available)
    if (instance.ctx.getNetworkManager()) |nm_ptr| {
        const async_curl: *AsyncCurlManager = @ptrCast(@alignCast(nm_ptr));

        // Create completion context for the async callback
        const completion_ctx = try allocator.create(FetchCompletionContext);

        completion_ctx.* = .{
            .promise_handle = promise_handle,
            .allocator = allocator,
            .engine = engine,
            .engine_ctx = engine_ctx,
            .runtime_ctx = instance.ctx,
        };

        // Get abort signal if provided (for in-flight abort support)
        const abort_signal: ?*runtime.Instance = if (init_data.wasPassed())
            init_data.getValue().signal
        else
            null;

        // Build NetworkRequest for async manager
        // Note: headers_list.items is a slice that survives until headers_list.deinit()
        // which happens after addRequest returns, so the headers are safely copied by curl
        const net_request = NetworkRequest{
            .url = url_str,
            .method = request_method,
            .headers = headers_list.items,
            .body = request_init.body,
            .follow_redirects = follow_redirects,
            // Wire up abort signal check for in-flight cancellation
            .abort_check = if (abort_signal != null) abortSignalCheck else null,
            .abort_check_data = if (abort_signal) |sig| @ptrCast(sig) else null,
        };

        // Add the async request - returns immediately
        _ = async_curl.addRequest(&net_request, asyncFetchCompletionCallback, completion_ctx) catch |err| {
            completion_ctx.deinit();
            return err;
        };

        // Async path: Promise is owned by the callback, don't clean it up.
        // Return the promise value directly - caller will NOT clean up the handle.
        const promise_obj = engine.getPromiseObject(promise_handle);
        return runtime.JSValue.fromHandle(promise_obj);
    }

    // FALLBACK: Synchronous path (no network manager)
    // This is used in tests or when Browser didn't set up async curl manager
    const result = global_fetch.globalFetch(allocator, .{ .url = url_str }, request_init);

    switch (result) {
        .response => |fetch_response| {
            // Get the InternalResponse from the fetch module's Response
            // We need to take ownership, so we'll extract and null out the internal
            const internal_response = fetch_response.internal;

            // Create a WebIDL Response instance wrapping the InternalResponse
            const response_instance = ResponseImpl.initWithInternalResponse(
                allocator,
                instance.ctx,
                internal_response,
            ) catch |err| {
                // On error, we need to clean up the internal response
                internal_response.deinit();
                // Also clean up the fetch Response wrapper (but not the internal we already handle)
                fetch_response.headers_obj.deinit();
                allocator.destroy(fetch_response);
                return err;
            };

            // Clean up the fetch Response wrapper without deiniting the internal
            // (ownership transferred to WebIDL Response)
            fetch_response.headers_obj.deinit();
            allocator.destroy(fetch_response);

            // Wrap the Response instance as a V8 object
            const wrapInstance = engine.wrapInstance orelse {
                return error.InvalidState;
            };

            const js_response = wrapInstance(engine_ctx, response_instance) catch {
                return error.InvalidState;
            };

            // Resolve the promise with the JS Response object
            engine.resolvePromise(engine_ctx, promise_handle, js_response) catch {};
        },
        .err => |fetch_err| {
            const fetch_error = switch (fetch_err) {
                global_fetch.FetchError.NetworkError => error.NetworkError,
                global_fetch.FetchError.AbortError => error.AbortError,
                global_fetch.FetchError.TypeError => error.TypeError,
                global_fetch.FetchError.OutOfMemory => error.OutOfMemory,
            };
            engine.rejectPromise(engine_ctx, promise_handle, fetch_error) catch {};
        },
    }

    // Sync path completed - return null to signal caller should clean up promise handle.
    return null;
}

// Helper to get promise object and destroy handle to prevent memory leaks
fn getPromiseAndCleanup(engine: *const runtime.EngineInterface, promise_handle: *anyopaque, allocator: std.mem.Allocator) runtime.JSValue {
    const promise_obj = engine.getPromiseObject(promise_handle);
    if (engine.destroyPromiseHandle) |destroy| {
        destroy(promise_handle, allocator);
    }
    return runtime.JSValue.fromHandle(promise_obj);
}

/// Check if headers list contains a header with the given name (case-insensitive).
/// This is a helper for BodyInit Content-Type detection.
fn headersListContains(headers: []const NetworkRequest.Header, name: []const u8) bool {
    for (headers) |header| {
        if (std.ascii.eqlIgnoreCase(header.name, name)) {
            return true;
        }
    }
    return false;
}
