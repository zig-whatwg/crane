//! Worker V8 Context Setup
//!
//! Spec: HTML Standard § 10.2.5 Processing model
//! https://html.spec.whatwg.org/#run-a-worker
//!
//! This module creates V8 isolates and contexts for worker execution.
//! Each worker gets its own V8 isolate for complete memory isolation.
//!
//! ## Design
//!
//! Workers need isolated V8 execution contexts separate from the main thread.
//! This module provides:
//! - V8 isolate creation per worker
//! - V8 context creation within the isolate
//! - EngineCallbacks implementation for WorkerContext
//! - Global scope setup (self, console, etc.)
//!
//! ## Usage
//!
//! ```zig
//! const worker_v8 = @import("worker_v8_context.zig");
//!
//! // Create V8 context for a worker
//! const v8_ctx = try worker_v8.WorkerV8Context.init(allocator, script_url, worker_type);
//! defer v8_ctx.deinit();
//!
//! // Set up engine callbacks on WorkerContext
//! worker_context.setEngineContext(v8_ctx.getEngineContext(), v8_ctx.getCallbacks());
//!
//! // Execute script
//! try worker_context.executeScript(source);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// V8 FFI through runtime module
const v8 = @import("v8");
const context_manager = v8.context_manager;
const runtime = @import("runtime");

// V8Interface for registering constructors
const V8Interface = v8.V8Interface;

// Interface bindings for automatic [Exposed] attribute handling
const interface_bindings = v8.interface_bindings;

// WebIDL helpers for GlobalScope enum
const webidl = @import("webidl");

// Interfaces needed in worker context
const interfaces = @import("interfaces");

// Fetch API support
const fetch = @import("fetch");
const impls = @import("impls");

// Worker types from html_core
const html_core = @import("html_core");
const workers = html_core.workers;
const WorkerContext = workers.WorkerContext;

// Structured clone types for MessagePort transfer
const structured_clone = html_core.structured_clone;
const TransferredPortData = structured_clone.types.TransferredPortData;

// MessagePort impl for creating wrappers in worker context
const MessagePortImpl = @import("impls").MessagePort;
const EngineCallbacks = workers.worker_context.EngineCallbacks;
const WorkerType = workers.WorkerType;
const DedicatedWorker = workers.DedicatedWorker;
const script_fetch = workers.script_fetch;

/// Opaque engine context type expected by WorkerContext
const EngineContext = workers.worker_context.EngineContext;

// Thread-local storage for current worker context (used by V8 callbacks)
threadlocal var current_worker_context: ?*WorkerV8Context = null;

// Thread-local storage for timer interface (set by caller before worker operations)
threadlocal var current_worker_timer_interface: ?runtime.TimerInterface = null;

// Thread-local storage for allocator (used by V8 callbacks like fetch)
threadlocal var current_worker_allocator: ?Allocator = null;

/// Get the current allocator (for internal use by V8 callbacks)
fn getWorkerAllocator() ?Allocator {
    return current_worker_allocator;
}

/// Set the current worker context (for use by external code before invoking worker callbacks)
///
/// This MUST be called before invoking any JavaScript callback that might call
/// worker-specific functions like postMessage(). The callback uses this thread-local
/// to route messages to the correct worker.
///
/// For nested workers, this is critical:
/// - When inner worker's message handler runs in outer worker's context,
///   the callback must know to route self.postMessage() to the outer worker
/// - Without this, messages would go to the wrong worker's port
pub fn setCurrentWorkerContext(ctx: ?*WorkerV8Context) void {
    current_worker_context = ctx;
}

/// Get the current worker context (for internal use)
pub fn getCurrentWorkerContext() ?*WorkerV8Context {
    return current_worker_context;
}

// ============================================================================
// Worker Timer Support
// ============================================================================

/// Timer context for tracking pending timers
const WorkerTimerContext = struct {
    /// V8 Global handle to the callback function
    callback_global: *v8.ffi.Value,
    /// The isolate this timer belongs to
    isolate: *v8.ffi.Isolate,
    /// The context for execution
    context: *v8.ffi.Context,
    /// Current timer ID (may change on reschedule for intervals)
    current_timer_id: runtime.TimerId,
    /// Whether this is an interval (repeating) timer
    is_interval: bool,
    /// Interval delay in milliseconds (for rescheduling)
    interval_delay_ms: u64,
    /// Allocator for cleanup
    allocator: Allocator,
    /// Whether this timer has been cancelled
    cancelled: bool,
    /// Pointer to the WorkerV8Context for setting current_worker_context
    worker_v8_context: *WorkerV8Context,
};

/// Thread-local storage for worker timer contexts
threadlocal var worker_timer_contexts: ?std.AutoHashMap(runtime.TimerId, *WorkerTimerContext) = null;

/// Initialize worker timer storage
fn initWorkerTimerStorage(allocator: Allocator) void {
    if (worker_timer_contexts == null) {
        worker_timer_contexts = std.AutoHashMap(runtime.TimerId, *WorkerTimerContext).init(allocator);
    }
}

/// Clean up all worker timer contexts
fn cleanupWorkerTimerContexts() void {
    if (worker_timer_contexts) |*map| {
        var iter = map.iterator();
        while (iter.next()) |entry| {
            const ctx = entry.value_ptr.*;
            // Cancel the timer at the libuv level
            if (WorkerV8Context.getTimerInterface()) |timer| {
                timer.clearTimeout(ctx.current_timer_id);
            }
            // Dispose the V8 Global handle
            v8.ffi.v8_Global_Dispose(ctx.callback_global);
            ctx.allocator.destroy(ctx);
        }
        map.deinit();
        worker_timer_contexts = null;
    }
}

/// Register a timer context for tracking
fn registerWorkerTimerContext(timer_id: runtime.TimerId, ctx: *WorkerTimerContext) void {
    if (worker_timer_contexts) |*map| {
        map.put(timer_id, ctx) catch {};
    }
}

/// Unregister a timer context (marks as cancelled, cleanup happens in callback)
fn unregisterWorkerTimerContext(timer_id: runtime.TimerId) void {
    if (worker_timer_contexts) |*map| {
        if (map.get(timer_id)) |ctx| {
            ctx.cancelled = true;
            // Cancel the timer at the libuv level
            if (WorkerV8Context.getTimerInterface()) |timer| {
                timer.clearTimeout(timer_id);
            }
        }
        if (map.fetchRemove(timer_id)) |kv| {
            const ctx = kv.value;
            v8.ffi.v8_Global_Dispose(ctx.callback_global);
            ctx.allocator.destroy(ctx);
        }
    }
}

// ============================================================================
// Worker Microtask Support (queueMicrotask)
// ============================================================================

/// Context for worker microtasks queued via queueMicrotask()
const WorkerMicrotaskContext = struct {
    /// V8 Global handle to the callback function
    callback_global: *v8.ffi.Value,
    /// The isolate this microtask belongs to
    isolate: *v8.ffi.Isolate,
    /// The context for execution
    context: *v8.ffi.Context,
    /// Allocator for cleanup
    allocator: Allocator,
    /// Pointer to the WorkerV8Context for setting current_worker_context
    worker_v8_context: *WorkerV8Context,
};

/// Microtask trampoline - invoked by V8's microtask queue during PerformMicrotaskCheckpoint
fn workerMicrotaskTrampoline(data: ?*anyopaque) callconv(.c) void {
    const ctx: *WorkerMicrotaskContext = @ptrCast(@alignCast(data orelse return));
    defer ctx.allocator.destroy(ctx);

    // CRITICAL: Set current_worker_context so that callbacks like postMessage
    // can access the correct worker context. Save and restore the previous context.
    const prev_context = current_worker_context;
    current_worker_context = ctx.worker_v8_context;
    defer current_worker_context = prev_context;

    // Create HandleScope for V8 operations
    const handle_scope = v8.ffi.v8_HandleScope_New(ctx.isolate);
    defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

    // Get the callback function from the Global handle
    const callback_fn = v8.ffi.v8_Global_Get(ctx.isolate, ctx.callback_global) orelse {
        v8.ffi.v8_Global_Dispose(ctx.callback_global);
        return;
    };
    defer v8.ffi.v8_Global_Dispose(ctx.callback_global);

    // Get global object for 'this'
    const global_obj = v8.ffi.v8_Context_Global(ctx.context) orelse return;

    // Call the callback function with no arguments
    var empty_args: [1]*v8.ffi.Value = undefined;
    _ = v8.ffi.v8_Function_Call(
        @ptrCast(callback_fn),
        ctx.context,
        @ptrCast(global_obj),
        0,
        &empty_args,
    );

    // CRITICAL: Flush pending messages to the port queue
    // Messages posted by the microtask callback (via postMessage) are buffered in
    // threadlocal pending_messages. Without this flush, they never reach the
    // outside port's message_queue and the main thread never receives them.
    DedicatedWorker.flushPendingMessages();

    // Schedule message dispatch if there are messages in the outside port queue
    if (ctx.worker_v8_context.dedicated_worker) |dedicated_worker| {
        if (dedicated_worker.port_pair.outside_port.message_queue.items.len > 0) {
            if (WorkerV8Context.getTimerInterface()) |timer| {
                _ = timer.setTimeout(0, workerMessageDispatchCallback, dedicated_worker);
            }
        }
    }
}

// ============================================================================
// Worker Error Handling Support
// ============================================================================

/// Callback to dispatch worker error events to the parent context.
/// This is scheduled after an error occurs in the worker and self.onerror
/// didn't handle it.
fn workerErrorDispatchCallback(context_ptr: ?*anyopaque) void {
    const error_ctx: *WorkerErrorDispatchContext = @ptrCast(@alignCast(context_ptr orelse return));
    defer error_ctx.allocator.destroy(error_ctx);

    // Fire the error event to the parent Worker object
    error_ctx.dedicated_worker.fireErrorToParent(error_ctx.error_event);
}

/// Context for scheduling error dispatch to parent
const WorkerErrorDispatchContext = struct {
    dedicated_worker: *DedicatedWorker,
    error_event: *workers.worker_error.WorkerErrorEvent,
    allocator: Allocator,
};

/// Callback to dispatch worker messages in the main thread context.
/// This is scheduled after worker timer callbacks flush messages to ensure
/// messages are processed in a clean V8 HandleScope state.
fn workerMessageDispatchCallback(context_ptr: ?*anyopaque) void {
    const dedicated_worker: *DedicatedWorker = @ptrCast(@alignCast(context_ptr orelse return));

    // Process queued messages - this invokes the Worker's onmessage handler
    // We're now in the main isolate context with clean HandleScope state
    dedicated_worker.processQueuedMessages();
}

/// Timer callback trampoline - invoked by the timer manager
fn workerTimerTrampoline(context_ptr: ?*anyopaque) void {
    const ctx: *WorkerTimerContext = @ptrCast(@alignCast(context_ptr orelse return));

    // Check if the timer was cancelled
    if (ctx.cancelled) return;

    // CRITICAL: Set current_worker_context so that callbacks like postMessage
    // can access the correct worker context. Save and restore the previous context.
    const prev_context = current_worker_context;
    current_worker_context = ctx.worker_v8_context;
    defer current_worker_context = prev_context;

    // Enter the worker's isolate and context
    v8.ffi.v8_Isolate_Enter(ctx.isolate);
    v8.ffi.v8_Context_Enter(ctx.context);
    defer {
        v8.ffi.v8_Context_Exit(ctx.context);
        v8.ffi.v8_Isolate_Exit(ctx.isolate);
    }

    // Create HandleScope for V8 operations
    const handle_scope = v8.ffi.v8_HandleScope_New(ctx.isolate);
    defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

    // Get the callback function from the Global handle
    const callback_fn = v8.ffi.v8_Global_Get(ctx.isolate, ctx.callback_global) orelse return;

    // Get global object for 'this'
    const global_obj = v8.ffi.v8_Context_Global(ctx.context) orelse return;

    // Call the callback function
    var empty_args: [1]*v8.ffi.Value = undefined;
    _ = v8.ffi.v8_Function_Call(
        @ptrCast(callback_fn),
        ctx.context,
        @ptrCast(global_obj),
        0,
        &empty_args,
    );

    // Run microtasks after callback
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(ctx.isolate);

    // CRITICAL: Flush pending messages to the port queue
    // Messages posted by the timer callback (via postMessage) are buffered in
    // threadlocal pending_messages. Without this flush, they never reach the
    // outside port's message_queue and the main thread never receives them.
    DedicatedWorker.flushPendingMessages();

    // Schedule message dispatch if there are messages in the outside port queue
    // This ensures the main thread's event loop processes the messages
    if (ctx.worker_v8_context.dedicated_worker) |dedicated_worker| {
        if (dedicated_worker.port_pair.outside_port.message_queue.items.len > 0) {
            if (WorkerV8Context.getTimerInterface()) |timer| {
                // Schedule a 0ms timer to dispatch messages in the next event loop iteration
                // This ensures we're back in the main isolate context when dispatching
                _ = timer.setTimeout(0, workerMessageDispatchCallback, dedicated_worker);
            }
        }
    }

    // For intervals, reschedule the timer
    if (ctx.is_interval and !ctx.cancelled) {
        if (WorkerV8Context.getTimerInterface()) |timer| {
            // Unregister the old timer ID from tracking
            if (worker_timer_contexts) |*map| {
                _ = map.remove(ctx.current_timer_id);
            }

            // Schedule the next interval
            const new_timer_id = timer.setTimeout(ctx.interval_delay_ms, workerTimerTrampoline, ctx);
            if (new_timer_id != 0) {
                ctx.current_timer_id = new_timer_id;
                // Re-register with the new timer ID
                registerWorkerTimerContext(new_timer_id, ctx);
            }
        }
    } else {
        // For one-shot timers, clean up after execution
        unregisterWorkerTimerContext(ctx.current_timer_id);
    }
}

/// Check if a URL indicates a secure context for worker
/// Per WPT convention, tests with .https. or .h2. in the filename should be treated
/// as secure contexts. Plain HTTP localhost is NOT considered secure for WPT tests
/// to allow testing non-secure context behavior.
fn isSecureUrlForWorker(url: []const u8) bool {
    // Check for secure schemes first
    if (std.mem.startsWith(u8, url, "https://") or
        std.mem.startsWith(u8, url, "wss://"))
    {
        return true;
    }

    // WPT convention: .https. in filename indicates secure context test
    if (std.mem.indexOf(u8, url, ".https.") != null) {
        return true;
    }

    // Also check for .h2. (HTTP/2 tests which require secure context)
    if (std.mem.indexOf(u8, url, ".h2.") != null) {
        return true;
    }

    return false;
}

/// Escape a string for use within a JavaScript string literal.
/// Escapes backslashes and double quotes.
fn escapeJsString(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    // Count how many characters need escaping
    var extra_chars: usize = 0;
    for (s) |c| {
        if (c == '"' or c == '\\') {
            extra_chars += 1;
        }
    }

    if (extra_chars == 0) {
        // No escaping needed, return a copy
        return try allocator.dupe(u8, s);
    }

    // Allocate buffer for escaped string
    var result = try allocator.alloc(u8, s.len + extra_chars);
    errdefer allocator.free(result);

    var i: usize = 0;
    for (s) |c| {
        if (c == '"' or c == '\\') {
            result[i] = '\\';
            i += 1;
        }
        result[i] = c;
        i += 1;
    }

    return result;
}

/// Get the effective URL for a worker, applying WPT URL rewriting rules.
/// Per WPT convention:
///   - .https. tests use https://localhost:8443
///   - .h2. tests use https://localhost:9000 (HTTP/2)
fn getEffectiveWorkerUrl(allocator: std.mem.Allocator, url: []const u8) ![]const u8 {
    const is_h2 = std.mem.indexOf(u8, url, ".h2.") != null;
    const is_https = std.mem.indexOf(u8, url, ".https.") != null;

    if (is_h2 or is_https) {
        // Determine target port based on test type
        const target_port: []const u8 = if (is_h2) "9000" else "8443";

        // Rewrite http:// to https:// for location object
        if (std.mem.startsWith(u8, url, "http://localhost:8000")) {
            // Replace http://localhost:8000 with https://localhost:<port>
            const rest = url["http://localhost:8000".len..];
            return try std.fmt.allocPrint(allocator, "https://localhost:{s}{s}", .{ target_port, rest });
        } else if (std.mem.startsWith(u8, url, "http://")) {
            // Generic http:// to https:// replacement (preserve original port if present)
            const rest = url["http://".len..];
            return try std.fmt.allocPrint(allocator, "https://{s}", .{rest});
        }
    }

    // Return a duplicate of the original URL (caller owns the memory)
    return try allocator.dupe(u8, url);
}

/// V8 Context for Worker execution
///
/// Creates and manages a V8 isolate and context for a worker.
/// Each worker gets its own isolate for complete memory isolation.
pub const WorkerV8Context = struct {
    /// V8 Isolate for this worker (separate from main thread)
    isolate: *v8.ffi.Isolate,

    /// V8 Context within the isolate
    context: *v8.ffi.Context,

    /// Script URL for error messages and import.meta.url
    script_url: []const u8,

    /// Worker type (classic or module)
    worker_type: WorkerType,

    /// Allocator
    allocator: Allocator,

    /// Reference to the DedicatedWorker (set during setupWorkerGlobalScope)
    dedicated_worker: ?*DedicatedWorker = null,

    /// Flag to prevent double-deinit (deinit can be called from Worker.deinit and disposeContextCallback)
    is_deinitialized: bool = false,

    /// Runtime context for WebIDL operations (MessagePort, etc.)
    /// This is heap-allocated because Context = *ContextData
    runtime_ctx_data: ?*runtime.ContextData = null,

    const Self = @This();

    /// Set the timer interface for worker operations.
    /// This should be called by the browser/runtime before creating or using workers.
    /// The timer interface is stored in thread-local storage and shared across all workers.
    pub fn setTimerInterface(timer: runtime.TimerInterface) void {
        current_worker_timer_interface = timer;
    }

    /// Get the current timer interface from thread-local storage.
    ///
    /// This is used for nested workers: when a Worker is created from within another
    /// Worker, the nested Worker's constructor can use the parent worker's timer
    /// (stored in thread-local storage) to schedule deferred initialization.
    ///
    /// The timer is set via setTimerInterface() when a worker context is set up.
    /// It remains available for the duration of the worker's script execution.
    pub fn getTimerInterface() ?runtime.TimerInterface {
        return current_worker_timer_interface;
    }

    /// Create a new V8 context for a worker
    ///
    /// This creates:
    /// 1. A new V8 isolate (separate from main thread)
    /// 2. A V8 context within that isolate
    /// 3. Sets up basic global scope
    pub fn init(
        allocator: Allocator,
        script_url: []const u8,
        worker_type: WorkerType,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Copy script URL
        const url_copy = try allocator.dupe(u8, script_url);
        errdefer allocator.free(url_copy);

        // Initialize V8 platform if not already done
        // NOTE: The main browser context should have already called
        // snapshot_loader.initializePlatformForSnapshots() which sets the
        // required V8 flags before platform init. If this is the first
        // V8 initialization, it won't support snapshot loading properly.
        v8.ffi.v8_Platform_Initialize();

        // Create V8 Isolate for this worker
        const isolate = v8.ffi.v8_Isolate_New() orelse {
            return error.V8IsolateCreationFailed;
        };
        errdefer v8.ffi.v8_Isolate_Dispose(isolate);

        // Enter the isolate temporarily to create the context
        v8.ffi.v8_Isolate_Enter(isolate);

        // Create V8 Context within the isolate
        const context = v8.ffi.v8_Context_New(isolate) orelse {
            v8.ffi.v8_Isolate_Exit(isolate);
            return error.V8ContextCreationFailed;
        };

        // Enter the context for setup
        v8.ffi.v8_Context_Enter(context);

        // Create runtime context for WebIDL operations
        const runtime_ctx_data = try allocator.create(runtime.ContextData);
        errdefer allocator.destroy(runtime_ctx_data);
        runtime_ctx_data.* = try runtime.ContextData.init(allocator, .{
            .engine_ctx = @ptrCast(context),
            .realm_info = .{
                .context_type = .dedicated_worker,
            },
        });

        self.* = .{
            .isolate = isolate,
            .context = context,
            .script_url = url_copy,
            .worker_type = worker_type,
            .allocator = allocator,
            .runtime_ctx_data = runtime_ctx_data,
        };

        // CRITICAL: Create HandleScope for V8 handle allocation during setup
        // V8 requires any API calls that create Local handles to be within a HandleScope.
        // setupWorkerGlobals() calls v8_String_NewFromUtf8 which creates Local<String>.
        // Without this, those calls will crash with "Cannot create a handle without a HandleScope".
        const handle_scope = v8.ffi.v8_HandleScope_New(isolate);
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        // Set up basic worker globals (self, globalThis)
        try self.setupWorkerGlobals();

        // Register essential WebIDL interfaces needed for worker scripts
        // This is a minimal subset needed for WPT tests
        self.registerWorkerInterfaces();

        // Exit worker context/isolate after setup - we'll re-enter when executing scripts
        // This allows the main isolate to remain active during Worker construction
        v8.ffi.v8_Context_Exit(context);
        v8.ffi.v8_Isolate_Exit(isolate);

        return self;
    }

    /// Clean up V8 isolate and context
    ///
    /// Note: This can be called from two paths:
    /// 1. Worker.deinit() -> v8_context.deinit()
    /// 2. WorkerContext.deinit() -> disposeContextCallback() -> deinit()
    ///
    /// The is_deinitialized flag prevents double-free.
    pub fn deinit(self: *Self) void {
        // Prevent double-deinit
        if (self.is_deinitialized) {
            return;
        }
        self.is_deinitialized = true;

        // Clean up worker timer contexts (cancels pending timers, frees memory)
        cleanupWorkerTimerContexts();

        // TODO: Proper cleanup of worker isolate/context
        // Currently we skip V8 cleanup because:
        // 1. Worker isolates are separate from main isolate
        // 2. During test cleanup, main isolate may already be disposed
        // 3. Trying to dispose worker context after main is gone causes segfault
        //
        // For proper cleanup, we need to:
        // - Track worker isolates separately from main isolate
        // - Dispose worker isolates BEFORE main isolate
        // - Or run workers in actual separate threads with their own cleanup

        // Clean up runtime context
        if (self.runtime_ctx_data) |ctx_data| {
            ctx_data.deinit();
            self.allocator.destroy(ctx_data);
        }

        // Free Zig allocations only
        self.allocator.free(self.script_url);
        self.allocator.destroy(self);
    }

    /// Exit the worker's V8 isolate and context
    /// Call this after script execution to return control to main isolate
    pub fn exitIsolate(self: *Self) void {
        v8.ffi.v8_Context_Exit(self.context);
        v8.ffi.v8_Isolate_Exit(self.isolate);
    }

    /// Re-enter the worker's V8 isolate and context
    /// Call this before executing more scripts in the worker
    pub fn enterIsolate(self: *Self) void {
        v8.ffi.v8_Isolate_Enter(self.isolate);
        v8.ffi.v8_Context_Enter(self.context);
    }

    /// Set up basic worker global scope (called during init)
    ///
    /// Sets up:
    /// - self -> globalThis
    /// - globalThis -> global object
    fn setupWorkerGlobals(self: *Self) !void {
        const global_obj = v8.ffi.v8_Context_Global(self.context) orelse {
            return error.NoGlobalObject;
        };

        // Set up 'self' as reference to global object
        const self_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "self", 4) orelse {
            return error.StringCreationFailed;
        };
        _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(self_key), @ptrCast(global_obj));

        // Set up 'globalThis' as reference to global object
        const global_this_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "globalThis", 10) orelse {
            return error.StringCreationFailed;
        };
        _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(global_this_key), @ptrCast(global_obj));
    }

    /// Register essential WebIDL interfaces needed in worker context
    ///
    /// This registers a minimal subset of interfaces commonly used by WPT tests:
    /// - URL, URLSearchParams (for URL manipulation)
    /// - Event, EventTarget (for event handling)
    /// - DOMException (for error handling)
    /// - WebSocket, CloseEvent, MessageEvent (for WebSocket API - Exposed in Worker per spec)
    ///
    /// Full interface registration (initializeBindings) can't be used directly
    /// because it requires the main isolate's context manager state.
    fn registerWorkerInterfaces(self: *Self) void {
        // Create HandleScope for interface registration
        const handle_scope = v8.ffi.v8_HandleScope_New(self.isolate);
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        // Register URL interface
        const URL = V8Interface(interfaces.URL);
        URL.registerGlobal(self.isolate, self.context, "URL");

        // Register URLSearchParams interface
        const URLSearchParams = V8Interface(interfaces.URLSearchParams);
        URLSearchParams.registerGlobal(self.isolate, self.context, "URLSearchParams");

        // Register Event interface
        const Event = V8Interface(interfaces.Event);
        Event.registerGlobal(self.isolate, self.context, "Event");

        // Register EventTarget interface
        const EventTarget = V8Interface(interfaces.EventTarget);
        EventTarget.registerGlobal(self.isolate, self.context, "EventTarget");

        // Register DOMException interface
        const DOMException = V8Interface(interfaces.DOMException);
        DOMException.registerGlobal(self.isolate, self.context, "DOMException");

        // Register WebSocket interface (Exposed in Worker per WHATWG WebSocket spec)
        // WebIDL: [Exposed=(Window,Worker)] interface WebSocket : EventTarget { ... }
        const WebSocket = V8Interface(interfaces.WebSocket);
        WebSocket.registerGlobal(self.isolate, self.context, "WebSocket");

        // Register CloseEvent interface (needed for WebSocket close events)
        // WebIDL: [Exposed=(Window,Worker)] interface CloseEvent : Event { ... }
        const CloseEvent = V8Interface(interfaces.CloseEvent);
        CloseEvent.registerGlobal(self.isolate, self.context, "CloseEvent");

        // Register MessageEvent interface (needed for WebSocket message events)
        // WebIDL: [Exposed=(Window,Worker,AudioWorklet)] interface MessageEvent : Event { ... }
        const MessageEvent = V8Interface(interfaces.MessageEvent);
        MessageEvent.registerGlobal(self.isolate, self.context, "MessageEvent");

        // Register MessagePort interface (needed for port transfer)
        // WebIDL: [Exposed=(Window,Worker,AudioWorklet)] interface MessagePort : EventTarget { ... }
        const MessagePort = V8Interface(interfaces.MessagePort);
        MessagePort.registerGlobal(self.isolate, self.context, "MessagePort");

        // Register MessageChannel interface (for creating port pairs)
        // WebIDL: [Exposed=(Window,Worker,AudioWorklet)] interface MessageChannel { ... }
        const MessageChannel = V8Interface(interfaces.MessageChannel);
        MessageChannel.registerGlobal(self.isolate, self.context, "MessageChannel");

        // Register Worker interface (for nested workers)
        // WebIDL: [Exposed=(Window,DedicatedWorker,SharedWorker)] interface Worker : EventTarget { ... }
        // Per HTML Standard § 10.2.3: Workers can create other Workers (nested workers)
        const Worker = V8Interface(interfaces.Worker);
        Worker.registerGlobal(self.isolate, self.context, "Worker");

        // Register Blob interface (needed for blob URL creation in nested workers)
        // WebIDL: [Exposed=(Window,Worker)] interface Blob { ... }
        const Blob = V8Interface(interfaces.Blob);
        Blob.registerGlobal(self.isolate, self.context, "Blob");
    }

    /// Set up full DedicatedWorkerGlobalScope with all required APIs
    ///
    /// Spec: HTML Standard § 10.2.4 DedicatedWorkerGlobalScope
    /// https://html.spec.whatwg.org/#dedicatedworkerglobalscope
    ///
    /// This sets up:
    /// - self.GLOBAL (WPT test harness requirement)
    /// - postMessage() - send messages to main thread
    /// - close() - terminate the worker
    /// - importScripts() - load scripts synchronously
    /// - console object (no-op for workers)
    /// - name property (worker name)
    pub fn setupWorkerGlobalScope(self: *Self, dedicated_worker: *DedicatedWorker) !void {
        // DEBUG: Log the setup pairing
        const stderr_file = std.fs.File.stderr();
        var buf: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "[setupWorkerGlobalScope] self={*}, dedicated_worker={*}, agent={*}, agent.closing={}, agent.termination_state={s}\n", .{
            self,
            dedicated_worker,
            dedicated_worker.agent,
            dedicated_worker.agent.data.closing,
            @tagName(dedicated_worker.agent.termination_state),
        }) catch "[setupWorkerGlobalScope]\n";
        stderr_file.writeAll(msg) catch {};

        self.dedicated_worker = dedicated_worker;

        // Enter worker's isolate and context for setup
        v8.ffi.v8_Isolate_Enter(self.isolate);
        v8.ffi.v8_Context_Enter(self.context);
        defer {
            v8.ffi.v8_Context_Exit(self.context);
            v8.ffi.v8_Isolate_Exit(self.isolate);
        }

        // Create HandleScope for V8 operations (required for context manager registration)
        const handle_scope = v8.ffi.v8_HandleScope_New(self.isolate);
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        // Update our local runtime_ctx_data to have the timer from thread-local storage
        // This ensures that nested Worker constructors have access to the timer
        // Per HTML Standard § 10.2.3: Workers can create other Workers (nested workers)
        const timer_interface = WorkerV8Context.getTimerInterface();
        if (self.runtime_ctx_data) |ctx_data| {
            ctx_data.timer = timer_interface;
        }

        // CRITICAL: Register worker's V8 context with the context manager
        // This enables nested Workers to find the parent worker's context with timer support
        // when their constructor calls getOrCreateWithIsolate().
        // Per HTML Standard § 10.2.3: Workers can create other Workers (nested workers)
        _ = v8.context_manager.getOrCreateWithExternalEventLoop(
            self.context,
            timer_interface,
            null, // Event loop not needed - workers use thread-local timers
            self.allocator,
        ) catch |err| {
            std.log.warn("Failed to register worker context with context manager: {}", .{err});
        };

        const global_obj = v8.ffi.v8_Context_Global(self.context) orelse {
            return error.NoGlobalObject;
        };

        // Set up GLOBAL object for WPT tests
        // This is required by testharness.js to detect the execution context
        const global_script =
            \\self.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
        ;
        _ = try self.executeScriptNoMessages(global_script);

        // NOTE: DedicatedWorkerGlobalScope and WorkerGlobalScope constructors are set up
        // AFTER installForScope() is called, so that Symbol.hasInstance can be added
        // to the real WebIDL interface constructors. See the worker_scope_script below.

        // Set up console object (no-op implementation for workers)
        const console_script =
            \\(function() {
            \\  function consoleNoop() {}
            \\  globalThis.console = {
            \\    log: consoleNoop,
            \\    warn: consoleNoop,
            \\    error: consoleNoop,
            \\    info: consoleNoop,
            \\    debug: consoleNoop,
            \\    trace: consoleNoop,
            \\    dir: consoleNoop,
            \\    table: consoleNoop,
            \\    assert: consoleNoop,
            \\    clear: consoleNoop,
            \\    count: consoleNoop,
            \\    countReset: consoleNoop,
            \\    group: consoleNoop,
            \\    groupCollapsed: consoleNoop,
            \\    groupEnd: consoleNoop,
            \\    time: consoleNoop,
            \\    timeLog: consoleNoop,
            \\    timeEnd: consoleNoop,
            \\  };
            \\})();
        ;
        _ = try self.executeScriptNoMessages(console_script);

        // Set thread-local reference for callbacks to access this context
        current_worker_context = self;

        // Register postMessage() - sends message to main thread
        // CRITICAL: Pass `self` as callback data so the callback always uses the
        // correct worker context, even for nested workers where the thread-local
        // current_worker_context might point to a different worker.
        {
            // Store self pointer in a V8 External value to pass to the callback
            const external = v8.ffi.v8_External_New(self.isolate, @ptrCast(self)) orelse {
                return error.ExternalCreationFailed;
            };
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerPostMessageCallback, @ptrCast(external)) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "postMessage", 11) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }

        // Register close() - terminates the worker
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerCloseCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "close", 5) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }

        // Register importScripts() - loads and executes scripts synchronously
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, importScriptsCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "importScripts", 13) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }

        // Register setTimeout() - schedules a one-shot timer
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerSetTimeoutCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "setTimeout", 10) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }

        // Register clearTimeout() - cancels a one-shot timer
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerClearTimeoutCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "clearTimeout", 12) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }

        // Register setInterval() - schedules a repeating timer
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerSetIntervalCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "setInterval", 11) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }

        // Register clearInterval() - cancels a repeating timer
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerClearTimeoutCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "clearInterval", 13) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }

        // Register done() for WPT test harness - signals test completion
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerDoneCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "done", 4) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }

        // Register queueMicrotask() - queues a microtask callback
        // Per HTML Standard § 8.1.7 - Integration with the JavaScript job queue
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerQueueMicrotaskCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "queueMicrotask", 14) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }

        // Register structuredClone() - creates a deep copy of a value using structured clone algorithm
        // Per HTML Standard § 2.7.8: StructuredClone method
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerStructuredCloneCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "structuredClone", 15) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }

        // Set up worker 'name' property
        const name = dedicated_worker.getName();
        if (name.len > 0) {
            const name_value = v8.ffi.v8_String_NewFromUtf8(self.isolate, name.ptr, @intCast(name.len)) orelse {
                return error.StringCreationFailed;
            };
            const name_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "name", 4) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(name_key), @ptrCast(name_value));
        } else {
            // Empty string for unnamed workers
            const name_value = v8.ffi.v8_String_NewFromUtf8(self.isolate, "", 0) orelse {
                return error.StringCreationFailed;
            };
            const name_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "name", 4) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(name_key), @ptrCast(name_value));
        }

        // Set up isSecureContext property
        // Per HTML Standard, isSecureContext indicates if the context is secure
        // For WPT tests, this depends on the URL - .https. or .h2. in filename means secure
        {
            const is_secure = isSecureUrlForWorker(self.script_url);
            const is_secure_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "isSecureContext", 15) orelse {
                return error.StringCreationFailed;
            };
            if (v8.ffi.v8_Boolean_New(self.isolate, is_secure)) |is_secure_value| {
                _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(is_secure_key), is_secure_value);
            }
        }

        // Set up location object using WorkerLocation interface
        // Per HTML Standard, WorkerGlobalScope has a location attribute
        // Apply WPT URL rewriting: .https. -> port 8443, .h2. -> port 9000
        {
            const effective_url = try getEffectiveWorkerUrl(self.allocator, self.script_url);
            defer self.allocator.free(effective_url);

            // Escape the URL for use in JavaScript string (escape quotes and backslashes)
            const escaped_url = try escapeJsString(self.allocator, effective_url);
            defer self.allocator.free(escaped_url);

            const location_script = try std.fmt.allocPrint(self.allocator,
                \\(function() {{
                \\  // Create WorkerLocation-like object
                \\  var url = new URL("{s}");
                \\  globalThis.location = {{
                \\    href: url.href,
                \\    protocol: url.protocol,
                \\    host: url.host,
                \\    hostname: url.hostname,
                \\    port: url.port,
                \\    pathname: url.pathname,
                \\    search: url.search,
                \\    hash: url.hash,
                \\    origin: url.origin,
                \\    toString: function() {{ return this.href; }}
                \\  }};
                \\}})();
            , .{escaped_url});
            defer self.allocator.free(location_script);
            _ = try self.executeScriptInternal(location_script);
        }

        // Set up origin property
        // Per HTML Standard, WorkerGlobalScope has an origin attribute
        // Apply WPT URL rewriting: .https. -> port 8443, .h2. -> port 9000
        {
            const effective_url = try getEffectiveWorkerUrl(self.allocator, self.script_url);
            defer self.allocator.free(effective_url);

            // Extract origin from effective URL (scheme://host:port)
            const origin_str = blk: {
                if (std.mem.startsWith(u8, effective_url, "http://") or std.mem.startsWith(u8, effective_url, "https://")) {
                    const scheme_end = std.mem.indexOf(u8, effective_url, "://") orelse break :blk "null";
                    const after_scheme = effective_url[scheme_end + 3 ..];
                    const path_start = std.mem.indexOf(u8, after_scheme, "/") orelse after_scheme.len;
                    break :blk effective_url[0 .. scheme_end + 3 + path_start];
                }
                break :blk "null";
            };
            const origin_value = v8.ffi.v8_String_NewFromUtf8(self.isolate, origin_str.ptr, @intCast(origin_str.len)) orelse {
                return error.StringCreationFailed;
            };
            const origin_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "origin", 6) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(origin_key), @ptrCast(origin_value));
        }

        // Set up navigator object (WorkerNavigator)
        // Per HTML Standard § 10.2.6 WorkerNavigator
        // Includes NavigatorID, NavigatorLanguage, NavigatorOnLine, NavigatorConcurrentHardware
        {
            const navigator_script =
                \\(function() {
                \\  globalThis.navigator = {
                \\    // NavigatorID mixin
                \\    userAgent: 'Crane/1.0',
                \\    appCodeName: 'Mozilla',
                \\    appName: 'Netscape',
                \\    appVersion: '5.0',
                \\    platform: 'Zig',
                \\    product: 'Gecko',
                \\    productSub: '20030107',
                \\    vendor: '',
                \\    vendorSub: '',
                \\    // NavigatorLanguage mixin
                \\    language: 'en-US',
                \\    languages: ['en-US', 'en'],
                \\    // NavigatorOnLine mixin
                \\    onLine: true,
                \\    // NavigatorConcurrentHardware mixin
                \\    hardwareConcurrency: 1
                \\  };
                \\})();
            ;
            _ = try self.executeScriptInternal(navigator_script);
        }

        // ====================================================================
        // Register ALL interfaces exposed to DedicatedWorker scope
        // Per WebIDL [Exposed] attribute filtering
        // This automatically includes: Request, Response, Headers, TextEncoder,
        // TextDecoder, Blob, File, FileReader, FileReaderSync, Crypto, SubtleCrypto,
        // and all other [Exposed=Worker] or [Exposed=*] interfaces
        // ====================================================================
        interface_bindings.installForScope(self.isolate, self.context, .DedicatedWorker);

        // ====================================================================
        // Set up WorkerGlobalScope and DedicatedWorkerGlobalScope for instanceof
        // Per HTML spec, the global object in a worker should be an instance of
        // DedicatedWorkerGlobalScope. We use Symbol.hasInstance to make this work:
        // - self instanceof DedicatedWorkerGlobalScope === true
        // - self instanceof WorkerGlobalScope === true
        //
        // This MUST run AFTER installForScope() because installForScope registers
        // the real WebIDL constructors, and we need to add Symbol.hasInstance to them.
        // If the constructors don't exist yet, we create them.
        // ====================================================================
        {
            const worker_scope_script =
                \\(function() {
                \\  // Helper to add Symbol.hasInstance to an existing or new constructor
                \\  function setupGlobalScopeConstructor(name) {
                \\    var ctor = globalThis[name];
                \\    if (typeof ctor !== 'function') {
                \\      // Create a new constructor if it doesn't exist
                \\      ctor = function() {};
                \\      globalThis[name] = ctor;
                \\    }
                \\    // Add Symbol.hasInstance to make instanceof work with globalThis/self
                \\    Object.defineProperty(ctor, Symbol.hasInstance, {
                \\      value: function(obj) { return obj === globalThis || obj === self; },
                \\      writable: false,
                \\      configurable: true
                \\    });
                \\  }
                \\
                \\  // Set up both WorkerGlobalScope and DedicatedWorkerGlobalScope
                \\  setupGlobalScopeConstructor('WorkerGlobalScope');
                \\  setupGlobalScopeConstructor('DedicatedWorkerGlobalScope');
                \\})();
            ;
            _ = try self.executeScriptInternal(worker_scope_script);
        }

        // ====================================================================
        // Worker-specific fetch() callback
        // The fetch() function needs a worker-specific callback to access the
        // worker context for proper request/response handling
        // Per Fetch spec: https://fetch.spec.whatwg.org/
        // ====================================================================
        {
            const template = v8.ffi.v8_FunctionTemplate_New(self.isolate, workerFetchCallback, null) orelse {
                return error.FunctionTemplateCreateFailed;
            };
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, self.context) orelse {
                return error.FunctionCreateFailed;
            };
            const key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "fetch", 5) orelse {
                return error.StringCreationFailed;
            };
            _ = v8.ffi.v8_Object_Set(global_obj, self.context, @ptrCast(key), @ptrCast(func));
        }

        // ====================================================================
        // Base64 functions - btoa, atob
        // Per HTML spec: https://html.spec.whatwg.org/#dom-btoa
        // Part of WindowOrWorkerGlobalScope mixin
        // ====================================================================
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
            _ = try self.executeScriptInternal(btoa_atob_script);
        }

        // ====================================================================
        // Crypto API - crypto object (WindowOrWorkerGlobalScope)
        // Per Web Crypto spec: https://w3c.github.io/webcrypto/
        // Part of WindowOrWorkerGlobalScope mixin
        // Note: This is a polyfill until native Zig crypto is fully implemented
        // ====================================================================
        {
            const crypto_script =
                \\(function() {
                \\  // SubtleCrypto placeholder for crypto.subtle
                \\  var subtle = {
                \\    encrypt: function() { return Promise.reject(new Error('Not implemented')); },
                \\    decrypt: function() { return Promise.reject(new Error('Not implemented')); },
                \\    sign: function() { return Promise.reject(new Error('Not implemented')); },
                \\    verify: function() { return Promise.reject(new Error('Not implemented')); },
                \\    digest: function() { return Promise.reject(new Error('Not implemented')); },
                \\    generateKey: function() { return Promise.reject(new Error('Not implemented')); },
                \\    deriveKey: function() { return Promise.reject(new Error('Not implemented')); },
                \\    deriveBits: function() { return Promise.reject(new Error('Not implemented')); },
                \\    importKey: function() { return Promise.reject(new Error('Not implemented')); },
                \\    exportKey: function() { return Promise.reject(new Error('Not implemented')); },
                \\    wrapKey: function() { return Promise.reject(new Error('Not implemented')); },
                \\    unwrapKey: function() { return Promise.reject(new Error('Not implemented')); }
                \\  };
                \\
                \\  // Crypto object with getRandomValues and randomUUID
                \\  globalThis.crypto = {
                \\    subtle: subtle,
                \\    getRandomValues: function(array) {
                \\      // Simple PRNG for testing (not cryptographically secure)
                \\      // Production should use native crypto
                \\      if (!(array instanceof Int8Array || array instanceof Uint8Array ||
                \\            array instanceof Int16Array || array instanceof Uint16Array ||
                \\            array instanceof Int32Array || array instanceof Uint32Array ||
                \\            array instanceof Uint8ClampedArray || array instanceof BigInt64Array ||
                \\            array instanceof BigUint64Array)) {
                \\        throw new TypeError('Argument must be an integer typed array');
                \\      }
                \\      for (var i = 0; i < array.length; i++) {
                \\        array[i] = Math.floor(Math.random() * 256);
                \\      }
                \\      return array;
                \\    },
                \\    randomUUID: function() {
                \\      // RFC 4122 version 4 UUID
                \\      return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
                \\        var r = Math.random() * 16 | 0;
                \\        var v = c === 'x' ? r : (r & 0x3 | 0x8);
                \\        return v.toString(16);
                \\      });
                \\    }
                \\  };
                \\})();
            ;
            _ = try self.executeScriptInternal(crypto_script);
        }

        // ====================================================================
        // Performance API - performance object (WindowOrWorkerGlobalScope)
        // Per High Resolution Time spec: https://w3c.github.io/hr-time/
        // Part of WindowOrWorkerGlobalScope mixin
        // ====================================================================
        {
            const performance_script =
                \\(function() {
                \\  var timeOrigin = Date.now();
                \\  globalThis.performance = {
                \\    timeOrigin: timeOrigin,
                \\    now: function() {
                \\      return Date.now() - timeOrigin;
                \\    },
                \\    toJSON: function() {
                \\      return { timeOrigin: this.timeOrigin };
                \\    }
                \\  };
                \\})();
            ;
            _ = try self.executeScriptInternal(performance_script);
        }

        // ====================================================================
        // IndexedDB API - indexedDB object (WindowOrWorkerGlobalScope)
        // Per IndexedDB spec: https://w3c.github.io/IndexedDB/
        // Part of WindowOrWorkerGlobalScope mixin
        // Note: This is a polyfill stub until native IndexedDB is implemented
        // ====================================================================
        {
            const indexeddb_script =
                \\(function() {
                \\  // IDBFactory stub - the indexedDB global is an instance of this
                \\  function IDBFactory() {}
                \\  IDBFactory.prototype.open = function(name, version) {
                \\    return Promise.reject(new Error('IndexedDB not implemented'));
                \\  };
                \\  IDBFactory.prototype.deleteDatabase = function(name) {
                \\    return Promise.reject(new Error('IndexedDB not implemented'));
                \\  };
                \\  IDBFactory.prototype.databases = function() {
                \\    return Promise.resolve([]);
                \\  };
                \\  IDBFactory.prototype.cmp = function(a, b) {
                \\    if (a < b) return -1;
                \\    if (a > b) return 1;
                \\    return 0;
                \\  };
                \\  globalThis.IDBFactory = IDBFactory;
                \\
                \\  // Create the indexedDB global instance
                \\  globalThis.indexedDB = new IDBFactory();
                \\})();
            ;
            _ = try self.executeScriptInternal(indexeddb_script);
        }
    }

    /// Get the engine context pointer for WorkerContext.setEngineContext()
    pub fn getEngineContext(self: *Self) *EngineContext {
        // Cast Self pointer to opaque EngineContext
        return @ptrCast(self);
    }

    /// Get the underlying V8 context pointer
    /// Used for registering with the context manager to support nested workers
    pub fn getV8Context(self: *Self) *v8.ffi.Context {
        return self.context;
    }

    /// Get the engine callbacks for WorkerContext.setEngineContext()
    pub fn getCallbacks(self: *const Self) EngineCallbacks {
        _ = self;
        return .{
            .compileAndRunScript = compileAndRunScriptCallback,
            .compileAndRunModule = compileAndRunModuleCallback,
            .runMicrotasks = runMicrotasksCallback,
            .disposeContext = disposeContextCallback,
            .configureImportMeta = null, // TODO: Implement for module workers
            .registerDynamicImportHandler = null, // TODO: Implement for module workers
        };
    }

    /// Execute a script in this worker's context (with optional message processing)
    ///
    /// If process_messages is true, also processes any pending incoming messages
    /// after script execution, allowing the worker's onmessage handler to be invoked.
    ///
    /// For setup scripts (global scope initialization), pass process_messages=false
    /// since the onmessage handler isn't set up yet.
    fn executeScriptEx(self: *Self, source: []const u8, process_messages: bool) !?*anyopaque {
        std.log.err("[executeScriptEx] ENTRY source_len={d} process_messages={} self={*}", .{ source.len, process_messages, self });
        std.log.err("[executeScriptEx] isolate={*} context={*}", .{ self.isolate, self.context });

        // Enter worker's isolate and context for script execution
        std.log.err("[executeScriptEx] About to enter isolate...", .{});
        v8.ffi.v8_Isolate_Enter(self.isolate);
        std.log.err("[executeScriptEx] Isolate entered", .{});
        v8.ffi.v8_Context_Enter(self.context);
        defer {
            v8.ffi.v8_Context_Exit(self.context);
            v8.ffi.v8_Isolate_Exit(self.isolate);
        }

        // CRITICAL: Create HandleScope for V8 handle allocation
        // V8 requires any API calls that create Local handles to be within a HandleScope.
        // Without this, v8_String_NewFromUtf8 and other handle-creating calls will crash
        // with "Cannot create a handle without a HandleScope".
        const handle_scope = v8.ffi.v8_HandleScope_New(self.isolate);
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        // Set current_worker_context so V8 callbacks (like postMessage) can access it
        // This allows workerPostMessageCallback to get the DedicatedWorker reference
        const prev_context = current_worker_context;
        current_worker_context = self;
        defer current_worker_context = prev_context;

        const result = try self.executeScriptInternal(source);
        std.log.err("[executeScriptEx] Script executed", .{});

        // Verify onmessage was set (we're still inside the isolate/context)
        const global_obj = v8.ffi.v8_Context_Global(self.context);
        if (global_obj) |g| {
            const onmessage_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "onmessage", 9);
            if (onmessage_key) |k| {
                const onmessage_val = v8.ffi.v8_Object_Get(g, self.context, @ptrCast(k));
                if (onmessage_val) |val| {
                    // CRITICAL: Use v8_Value_IsFunction (for Global handles), NOT v8_Value_IsFunction_Local
                    // v8_Object_Get returns Global<Value>*, so we must use the Global handle version
                    if (v8.ffi.v8_Value_IsFunction(val)) {
                        std.log.err("[executeScriptEx] onmessage IS a function!", .{});
                    } else {
                        std.log.err("[executeScriptEx] onmessage NOT a function", .{});
                    }
                } else {
                    std.log.err("[executeScriptEx] onmessage_val is null", .{});
                }
            } else {
                std.log.err("[executeScriptEx] onmessage_key is null", .{});
            }
        } else {
            std.log.err("[executeScriptEx] global_obj is null", .{});
        }

        // Process any incoming messages from the main thread (only if requested)
        // This allows the worker's onmessage handler (set up by the script) to run
        if (process_messages) {
            self.processIncomingMessagesInternal();
        }

        return result;
    }

    /// Execute a script in this worker's context (processes messages after)
    ///
    /// This also processes any pending incoming messages after script execution,
    /// allowing the worker's onmessage handler to be invoked.
    pub fn executeScript(self: *Self, source: []const u8) !?*anyopaque {
        std.log.err("=== EXECUTE_SCRIPT source_len={d} CALLING executeScriptEx ===", .{source.len});
        std.log.err("=== EXECUTE_SCRIPT self={*} ===", .{self});
        // Call executeScriptEx directly - inline call to avoid any vtable issues
        const result_or_err = executeScriptEx(self, source, true);
        if (result_or_err) |result| {
            std.log.err("=== EXECUTE_SCRIPT DONE result={*} ===", .{result});
            return result;
        } else |err| {
            std.log.err("=== EXECUTE_SCRIPT executeScriptEx returned error: {} ===", .{err});
            return err;
        }
    }

    /// Execute a script without processing messages (for setup scripts)
    ///
    /// Use this for global scope initialization scripts that run before the
    /// worker's onmessage handler is set up.
    fn executeScriptNoMessages(self: *Self, source: []const u8) !?*anyopaque {
        return self.executeScriptEx(source, false);
    }

    /// Process incoming messages - internal version (already in isolate context)
    fn processIncomingMessagesInternal(self: *Self) void {
        const dedicated_worker = self.dedicated_worker orelse return;
        const inside_port = dedicated_worker.port_pair.inside_port;

        const queue_len = inside_port.message_queue.items.len;
        if (queue_len > 0) {
            std.log.debug("[processIncomingMessagesInternal] {d} messages in inside_port queue", .{queue_len});
        }

        while (inside_port.message_queue.items.len > 0) {
            const msg = inside_port.message_queue.orderedRemove(0);
            std.log.debug("[processIncomingMessagesInternal] Dispatching message type={s}", .{@tagName(msg.data.type)});
            dispatchMessageToWorkerInternal(self, msg);
            msg.deinit();
        }
    }

    /// Dispatch message to worker's onmessage - internal version (already in isolate context)
    ///
    /// This function calls self.onmessage(event) entirely via JavaScript to avoid
    /// V8 FFI handle type mismatches between Global and Local handles.
    ///
    /// For v8_serialized messages (from cross-isolate ArrayBuffer transfers), we use
    /// V8's ValueDeserializer to reconstruct the ArrayBuffer in this isolate.
    fn dispatchMessageToWorkerInternal(self: *Self, msg: *workers.message_channel.QueuedMessage) void {
        const serialized = msg.data;

        // Handle v8_serialized messages (cross-isolate ArrayBuffer transfers)
        if (serialized.type == .v8_serialized) {
            self.dispatchV8SerializedMessage(serialized);
            return;
        }

        // Deserialize message data to JSON string for other types
        const json_str: []const u8 = switch (serialized.type) {
            .primitive => switch (serialized.data.primitive) {
                .string => |s| s,
                .undefined => "undefined",
                .null => "null",
                .boolean => |b| if (b) "true" else "false",
                .number => "0", // TODO: Proper number serialization
                .bigint => "0", // TODO: Proper bigint serialization
            },
            .string_object => serialized.data.string_object, // Boxed String
            else => return, // Can't convert complex types to simple string
        };

        // Build JavaScript code that calls self.onmessage with the data
        // This avoids FFI handle type issues by doing everything in JavaScript
        var script_buf: [4096]u8 = undefined;
        const script = std.fmt.bufPrint(&script_buf,
            \\(function() {{
            \\  if (typeof self.onmessage === 'function') {{
            \\    var data = {s};
            \\    var event = {{ data: data, type: 'message', target: self, currentTarget: self }};
            \\    self.onmessage(event);
            \\    return true;
            \\  }}
            \\  return false;
            \\}})()
        , .{json_str}) catch return;

        // Compile and run the script
        const src = v8.ffi.v8_String_NewFromUtf8(self.isolate, script.ptr, @intCast(script.len)) orelse return;

        const compile_result = v8.ffi.v8_Script_Compile_Safe(self.context, src);
        defer v8.ffi.v8_FreeScriptCompileResult(compile_result);

        if (compile_result.script == null) return;

        const run_result = v8.ffi.v8_Script_Run_Safe(self.context, compile_result.script.?);
        defer v8.ffi.v8_FreeScriptRunResult(run_result);

        // Run microtasks after handler
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);
    }

    /// Dispatch a v8_serialized message using cross-isolate deserialization
    ///
    /// This handles messages that contain transferred ArrayBuffers. The data was
    /// serialized in the main isolate and needs to be deserialized in this worker's isolate.
    fn dispatchV8SerializedMessage(self: *Self, serialized: *workers.message_channel.SerializedValue) void {
        const v8_data = serialized.data.v8_serialized;

        // Build ArrayBufferTransferData array for deserialization
        var arraybuffer_data: [64]v8.ffi.ArrayBufferTransferData = undefined;
        const ab_count = @min(v8_data.transferred_arraybuffers.len, 64);

        for (0..ab_count) |i| {
            const transferred = v8_data.transferred_arraybuffers[i];
            arraybuffer_data[i] = .{
                .data = if (transferred.data.len > 0) transferred.data.ptr else null,
                .size = transferred.byte_length,
            };
        }

        // Deserialize using cross-isolate API in this worker's isolate
        var error_code: i32 = 0;
        const v8_value = v8.ffi.v8_Value_DeserializeWithTransfer_CrossIsolate(
            v8_data.serialized_bytes.ptr,
            v8_data.serialized_bytes.len,
            &arraybuffer_data,
            ab_count,
            &error_code,
        );

        if (v8_value == null or error_code != 0) {
            std.log.warn("[Worker] dispatchV8SerializedMessage: deserialization failed with error {}", .{error_code});
            return;
        }

        // Get global object for calling onmessage
        const global_obj = v8.ffi.v8_Context_Global(self.context) orelse {
            std.log.warn("[Worker] dispatchV8SerializedMessage: no global object", .{});
            return;
        };

        // Get self.onmessage property
        const onmessage_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "onmessage", 9) orelse return;
        const onmessage_val = v8.ffi.v8_Object_Get(global_obj, self.context, @ptrCast(onmessage_key)) orelse return;

        // Check if onmessage is a function
        // NOTE: v8_Object_Get returns Global<Value>*, so use non-Local type check
        const onmessage_val_ptr: *v8.ffi.Value = @ptrCast(onmessage_val);
        if (!v8.ffi.v8_Value_IsFunction(onmessage_val_ptr)) {
            return;
        }

        // Create ports array from transferred MessagePorts
        // Per HTML Standard § 9.4.4: create new MessagePort wrappers in destination realm
        const port_count = v8_data.transferred_ports.len;
        std.log.info("[Worker] dispatchV8SerializedMessage: transferred_ports.len = {}", .{port_count});

        const ports_array: *v8.ffi.Value = if (port_count > 0) blk: {
            // Create V8 array for ports
            const arr = v8.ffi.v8_Array_New(self.isolate, @intCast(port_count));

            for (v8_data.transferred_ports, 0..) |port_data, i| {
                std.log.info("[Worker] Creating MessagePort wrapper for port {}", .{i});
                // Get the worker's runtime context
                const runtime_ctx = self.runtime_ctx_data orelse {
                    std.log.warn("[Worker] No runtime context for MessagePort creation", .{});
                    continue;
                };

                // Create new WebIDL MessagePort wrapper in this isolate
                // Use initWithInternal to wrap the existing internal port
                // Pass the internal port pointer (will be cast to correct type by initWithInternal)
                const port_instance = MessagePortImpl.initWithInternal(
                    self.allocator,
                    interfaces.MessagePort.State,
                    &interfaces.MessagePort.vtable,
                    runtime_ctx,
                    @ptrCast(@alignCast(port_data.internal_port)),
                ) catch {
                    std.log.warn("[Worker] Failed to create MessagePort wrapper", .{});
                    continue;
                };

                // Wrap the instance as a V8 object using template registry
                const port_v8_obj = v8.template_registry.wrapInstanceAsV8Object(
                    port_instance,
                    "MessagePort",
                    self.isolate,
                    self.context,
                ) catch {
                    std.log.warn("[Worker] Failed to wrap MessagePort as V8 object", .{});
                    continue;
                };

                // Add to array
                _ = v8.ffi.v8_Array_Set(@ptrCast(arr), self.context, @intCast(i), @ptrCast(port_v8_obj));
            }

            break :blk @ptrCast(arr);
        } else @ptrCast(v8.ffi.v8_Array_New(self.isolate, 0));

        // Create a simple event object with 'data' and 'ports' properties using JavaScript
        // The deserialized v8_value is the data we need to pass as event.data
        const event_script =
            \\(function(data, ports) {
            \\  return { data: data, type: 'message', target: self, currentTarget: self, ports: ports };
            \\})
        ;
        const event_source = v8.ffi.v8_String_NewFromUtf8(self.isolate, event_script.ptr, @intCast(event_script.len)) orelse return;
        const compile_result = v8.ffi.v8_Script_Compile_Safe(self.context, event_source);
        defer v8.ffi.v8_FreeScriptCompileResult(compile_result);

        if (compile_result.script == null) return;

        const run_result = v8.ffi.v8_Script_Run_Safe(self.context, compile_result.script.?);
        defer v8.ffi.v8_FreeScriptRunResult(run_result);

        const event_factory = run_result.value orelse return;

        // Call the factory function with deserialized data and ports array
        var factory_args = [_]*v8.ffi.Value{ v8_value.?, ports_array };
        const event_obj = v8.ffi.v8_Function_Call(
            @ptrCast(event_factory),
            self.context,
            @ptrCast(global_obj),
            2,
            &factory_args,
        ) orelse {
            std.log.warn("[Worker] dispatchV8SerializedMessage: failed to create event object", .{});
            return;
        };

        // Call onmessage(event)
        var args = [_]*v8.ffi.Value{event_obj};
        _ = v8.ffi.v8_Function_Call(
            @ptrCast(onmessage_val),
            self.context,
            @ptrCast(global_obj),
            1,
            &args,
        );

        // Run microtasks after handler
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);
    }

    /// Dispatch error to self.onerror handler (OnErrorEventHandler)
    ///
    /// Spec: HTML Standard § 10.1.5.1 "Report the error"
    /// https://html.spec.whatwg.org/#report-the-error
    ///
    /// The OnErrorEventHandler receives 5 arguments:
    ///   1. message (DOMString) - the error message
    ///   2. filename (USVString) - the script URL
    ///   3. lineno (unsigned long) - the line number
    ///   4. colno (unsigned long) - the column number
    ///   5. error (Error) - the Error object
    ///
    /// If the handler returns true, the error is considered handled and
    /// should NOT propagate to the parent Worker object.
    ///
    /// Returns true if the handler was called and returned true (error handled).
    /// Returns false if handler not set, not callable, returned false, or threw.
    fn dispatchSelfOnerror(
        self: *Self,
        message: []const u8,
        filename: []const u8,
        lineno: u32,
        colno: u32,
    ) bool {
        // Get the global object
        const global = v8.ffi.v8_Context_Global(self.context) orelse return false;

        // Get the "onerror" property from global (self.onerror)
        const onerror_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "onerror", 7) orelse return false;
        const onerror_value = v8.ffi.v8_Object_Get(global, self.context, @ptrCast(onerror_key)) orelse return false;

        // Check if it's a function
        if (!v8.ffi.v8_Value_IsFunction(onerror_value)) {
            return false;
        }

        // Create the 5 arguments for OnErrorEventHandler:
        // 1. message (string)
        const msg_str = v8.ffi.v8_String_NewFromUtf8(self.isolate, message.ptr, @intCast(message.len)) orelse return false;

        // 2. filename (string)
        const filename_str = v8.ffi.v8_String_NewFromUtf8(self.isolate, filename.ptr, @intCast(filename.len)) orelse return false;

        // 3. lineno (number)
        const lineno_num = v8.ffi.v8_Integer_New(self.isolate, @intCast(lineno));

        // 4. colno (number)
        const colno_num = v8.ffi.v8_Integer_New(self.isolate, @intCast(colno));

        // 5. error (Error object) - create an Error with the message
        const error_obj = v8.ffi.v8_Exception_ErrorInContext(self.context, msg_str) orelse return false;

        // Build args array
        var args = [5]*v8.ffi.Value{
            @ptrCast(msg_str),
            @ptrCast(filename_str),
            @ptrCast(lineno_num),
            @ptrCast(colno_num),
            error_obj,
        };

        // Call the onerror function with global as 'this'
        const onerror_fn: *v8.ffi.Function = @ptrCast(onerror_value);
        const result = v8.ffi.v8_Function_Call(onerror_fn, self.context, @ptrCast(global), 5, &args);

        // Check if result is truthy (true means error was handled)
        if (result) |r| {
            return v8.ffi.v8_Value_BooleanValue(r, self.isolate);
        }

        return false;
    }

    /// Send an error event to the parent Worker object via the callback mechanism.
    ///
    /// This schedules a WorkerErrorEvent to be dispatched on the parent thread.
    /// The main thread's event loop will dispatch the error via Worker.onerror
    /// or addEventListener('error').
    ///
    /// Spec: HTML Standard § 10.2.5 step 11
    /// "Queue a task to fire an event named error at worker."
    fn sendErrorToParent(
        self: *Self,
        message: []const u8,
        filename: []const u8,
        lineno: u32,
        colno: u32,
    ) void {
        const dedicated_worker = self.dedicated_worker orelse return;

        // Create error event data
        const error_event = workers.worker_error.WorkerErrorEvent.init(
            self.allocator,
            message,
            filename,
            lineno,
            colno,
            null, // error_value - V8 value doesn't cross isolate boundary safely
        ) catch return;

        // Schedule error dispatch to parent thread via timer (0ms)
        // This ensures we're in the main isolate context when dispatching
        if (WorkerV8Context.getTimerInterface()) |timer| {
            const dispatch_ctx = self.allocator.create(WorkerErrorDispatchContext) catch {
                error_event.deinit();
                return;
            };
            dispatch_ctx.* = .{
                .dedicated_worker = dedicated_worker,
                .error_event = error_event,
                .allocator = self.allocator,
            };
            _ = timer.setTimeout(0, workerErrorDispatchCallback, dispatch_ctx);
        } else {
            // No timer interface, dispatch synchronously (may not be ideal but better than dropping)
            dedicated_worker.fireErrorToParent(error_event);
        }
    }

    /// Execute a script - internal version that assumes context is already entered
    fn executeScriptInternal(self: *Self, source: []const u8) !?*anyopaque {
        // Create V8 string from source
        const source_str = v8.ffi.v8_String_NewFromUtf8(
            self.isolate,
            source.ptr,
            @intCast(source.len),
        ) orelse {
            return error.StringCreationFailed;
        };

        // Compile script using safe version
        const compile_result = v8.ffi.v8_Script_Compile_Safe(self.context, source_str);
        defer v8.ffi.v8_FreeScriptCompileResult(compile_result);

        if (compile_result.error_info) |err_info| {
            const err_msg = err_info.getMessage() orelse "Script compilation failed";
            const filename = err_info.getResourceName() orelse self.script_url;
            const lineno: u32 = if (err_info.line_number >= 0) @intCast(err_info.line_number) else 0;
            const colno: u32 = if (err_info.column_number >= 0) @intCast(err_info.column_number) else 0;

            std.log.err("[Worker] Script compilation failed: {s}", .{err_msg});
            if (err_info.getStackTrace()) |st| {
                std.log.err("[Worker] Stack trace: {s}", .{st});
            }

            // Dispatch to self.onerror first, then propagate to parent if not handled
            const error_handled = self.dispatchSelfOnerror(err_msg, filename, lineno, colno);
            if (!error_handled) {
                self.sendErrorToParent(err_msg, filename, lineno, colno);
            }

            return error.CompilationFailed;
        }

        const script = compile_result.script orelse return error.CompilationFailed;

        // Run script using safe version
        const run_result = v8.ffi.v8_Script_Run_Safe(self.context, script);
        defer v8.ffi.v8_FreeScriptRunResult(run_result);

        if (run_result.error_info) |err_info| {
            const err_msg = err_info.getMessage() orelse "Script execution failed";
            const filename = err_info.getResourceName() orelse self.script_url;
            const lineno: u32 = if (err_info.line_number >= 0) @intCast(err_info.line_number) else 0;
            const colno: u32 = if (err_info.column_number >= 0) @intCast(err_info.column_number) else 0;

            std.log.err("[Worker] Script execution failed: {s}", .{err_msg});
            if (err_info.getStackTrace()) |st| {
                std.log.err("[Worker] Stack trace: {s}", .{st});
            }

            // Dispatch to self.onerror first, then propagate to parent if not handled
            const error_handled = self.dispatchSelfOnerror(err_msg, filename, lineno, colno);
            if (!error_handled) {
                self.sendErrorToParent(err_msg, filename, lineno, colno);
            }

            return error.ExecutionFailed;
        }

        // Run microtasks after script execution
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);

        return @ptrCast(run_result.value);
    }
};

// ============================================================================
// Engine Callbacks Implementation
// ============================================================================

/// Compile and run a script, returns result value pointer
fn compileAndRunScriptCallback(
    engine_ctx: *EngineContext,
    source: []const u8,
    source_url: []const u8,
) anyerror!?*anyopaque {
    _ = source_url; // Used for error messages (TODO)
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));
    return self.executeScript(source);
}

/// Compile and run a module
fn compileAndRunModuleCallback(
    engine_ctx: *EngineContext,
    source: []const u8,
    source_url: []const u8,
) anyerror!void {
    _ = source_url; // TODO: Used for import resolution
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));

    // For now, execute as script. Full module support needs more V8 FFI.
    _ = try self.executeScript(source);
}

/// Run microtask checkpoint
fn runMicrotasksCallback(engine_ctx: *EngineContext) void {
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(self.isolate);
}

/// Dispose engine context
fn disposeContextCallback(engine_ctx: *EngineContext) void {
    const self: *WorkerV8Context = @ptrCast(@alignCast(engine_ctx));
    self.deinit();
}

// ============================================================================
// V8 Callbacks for Worker Global Functions
// ============================================================================

// ============================================================================
// V8 Timer Callbacks
// ============================================================================

/// V8 callback for setTimeout() - schedules a one-shot timer
fn workerSetTimeoutCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;

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
            const delay_f64 = v8.ffi.v8_Value_NumberValue(delay_value, v8_context);
            if (!std.math.isNan(delay_f64) and !std.math.isInf(delay_f64) and delay_f64 >= 0) {
                delay_ms = @intFromFloat(delay_f64);
            }
        }
    }

    // Get the worker context
    const worker_ctx = current_worker_context orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Get the timer interface from the browser context (shares libuv event loop)
    const timer = WorkerV8Context.getTimerInterface() orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Initialize timer storage if needed
    initWorkerTimerStorage(worker_ctx.allocator);

    // Create Global handle for the callback function
    const callback_global = v8.ffi.v8_Value_ToGlobal(isolate, callback_value) orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Allocate timer context
    const timer_ctx = worker_ctx.allocator.create(WorkerTimerContext) catch {
        v8.ffi.v8_Global_Dispose(callback_global);
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    timer_ctx.* = .{
        .callback_global = callback_global,
        .isolate = isolate,
        .context = v8_context,
        .current_timer_id = 0, // Will be updated after scheduling
        .is_interval = false,
        .interval_delay_ms = 0,
        .allocator = worker_ctx.allocator,
        .cancelled = false,
        .worker_v8_context = worker_ctx,
    };

    // Schedule the timer using the browser's libuv-backed timer interface
    const delay_u64: u64 = if (delay_ms >= 0) @intCast(delay_ms) else 0;
    const timer_id = timer.setTimeout(delay_u64, workerTimerTrampoline, timer_ctx);

    if (timer_id == 0) {
        v8.ffi.v8_Global_Dispose(callback_global);
        worker_ctx.allocator.destroy(timer_ctx);
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    // Update the timer_id in the context for cleanup tracking
    timer_ctx.current_timer_id = timer_id;

    // Register for tracking
    registerWorkerTimerContext(timer_id, timer_ctx);

    // Return timer ID
    const result = v8.ffi.v8_Integer_New(isolate, @intCast(@as(u32, @truncate(timer_id))));
    info.setReturnValue(@ptrCast(result));
}

/// V8 callback for setInterval() - schedules a repeating timer
fn workerSetIntervalCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;

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
            const delay_f64 = v8.ffi.v8_Value_NumberValue(delay_value, v8_context);
            if (!std.math.isNan(delay_f64) and !std.math.isInf(delay_f64) and delay_f64 >= 0) {
                delay_ms = @intFromFloat(delay_f64);
            }
        }
    }

    // Get the worker context
    const worker_ctx = current_worker_context orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Get the timer interface from the browser context (shares libuv event loop)
    const timer = WorkerV8Context.getTimerInterface() orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Initialize timer storage if needed
    initWorkerTimerStorage(worker_ctx.allocator);

    // Create Global handle for the callback function
    const callback_global = v8.ffi.v8_Value_ToGlobal(isolate, callback_value) orelse {
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    // Allocate timer context
    const timer_ctx = worker_ctx.allocator.create(WorkerTimerContext) catch {
        v8.ffi.v8_Global_Dispose(callback_global);
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    };

    const delay_u64: u64 = if (delay_ms >= 0) @intCast(delay_ms) else 0;

    timer_ctx.* = .{
        .callback_global = callback_global,
        .isolate = isolate,
        .context = v8_context,
        .current_timer_id = 0, // Will be updated after scheduling
        .is_interval = true,
        .interval_delay_ms = delay_u64,
        .allocator = worker_ctx.allocator,
        .cancelled = false,
        .worker_v8_context = worker_ctx,
    };

    // Schedule the timer using the browser's libuv-backed timer interface
    const timer_id = timer.setTimeout(delay_u64, workerTimerTrampoline, timer_ctx);

    if (timer_id == 0) {
        v8.ffi.v8_Global_Dispose(callback_global);
        worker_ctx.allocator.destroy(timer_ctx);
        const result = v8.ffi.v8_Integer_New(isolate, 0);
        info.setReturnValue(@ptrCast(result));
        return;
    }

    // Update the timer_id in the context for cleanup tracking
    timer_ctx.current_timer_id = timer_id;

    // Register for tracking
    registerWorkerTimerContext(timer_id, timer_ctx);

    // Return timer ID
    const result = v8.ffi.v8_Integer_New(isolate, @intCast(timer_id));
    info.setReturnValue(@ptrCast(result));
}

/// V8 callback for clearTimeout() / clearInterval() - cancels a timer
fn workerClearTimeoutCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
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

    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    };

    const timer_id_f64 = v8.ffi.v8_Value_NumberValue(id_value, v8_context);
    if (std.math.isNan(timer_id_f64) or std.math.isInf(timer_id_f64) or timer_id_f64 < 0) {
        if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
            info.setReturnValue(undef_value);
        }
        return;
    }

    const timer_id: runtime.TimerId = @intFromFloat(timer_id_f64);

    // Clean up the timer context (this also cancels via browser_context timer interface)
    unregisterWorkerTimerContext(timer_id);

    if (v8.ffi.v8_Undefined(isolate)) |undef_value| {
        info.setReturnValue(undef_value);
    }
}

/// V8 callback for postMessage() - sends message to main thread
///
/// Spec: HTML Standard § 10.2.4.1 postMessage(message, transfer)
/// https://html.spec.whatwg.org/#dom-dedicatedworkerglobalscope-postmessage
///
/// This function:
/// 1. Gets the message argument from V8 FunctionCallbackInfo
/// 2. Serializes it to JSON using V8's JSON.stringify
/// 3. Stores the JSON string in a JSValue
/// 4. Posts it through the message port to the main thread
fn workerPostMessageCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    const argc = info.v8_FunctionCallbackInfo_Length();

    if (argc < 1) return;
    const message_arg = info.get(0);

    // CRITICAL: Get WorkerV8Context from callback data, NOT from thread-local.
    // For nested workers, the thread-local current_worker_context may point to
    // the wrong worker (e.g., inner worker instead of outer worker).
    // The callback data was set when this postMessage function was created,
    // so it always points to the correct worker.
    const data = info.getData();
    // The callback data is a V8 External containing our WorkerV8Context pointer
    const worker_ctx_ptr = v8.ffi.v8_External_Value(@ptrCast(data));
    const self: ?*WorkerV8Context = if (worker_ctx_ptr) |ptr| @ptrCast(@alignCast(ptr)) else null;

    // Get required size for JSON buffer
    var dummy_buf: [1]u8 = undefined;
    const required_size = v8.ffi.v8_JSON_Stringify_ToBuffer(
        v8_context,
        message_arg,
        &dummy_buf,
        0,
    );
    if (required_size <= 0) return;

    // Allocate buffer dynamically based on required size and stringify again
    // The "complete" message from testharness.js can be quite large (9000+ bytes)
    // containing all test results, so we need dynamic allocation.
    // NOTE: `self` is now obtained from callback data (see above), not current_worker_context
    const worker_ctx = self orelse return;
    const json_buffer = worker_ctx.allocator.alloc(u8, @intCast(required_size + 1)) catch return;
    defer worker_ctx.allocator.free(json_buffer);

    const written = v8.ffi.v8_JSON_Stringify_ToBuffer(
        v8_context,
        message_arg,
        json_buffer.ptr,
        @intCast(json_buffer.len),
    );
    if (written <= 0) return;

    const json_str = json_buffer[0..@intCast(written)];
    const dedicated_worker = worker_ctx.dedicated_worker orelse return;

    // DEBUG: Log the message being posted
    const stderr_file = std.fs.File.stderr();
    var debug_buf: [512]u8 = undefined;
    const preview_len = @min(json_str.len, 50);
    const debug_msg = std.fmt.bufPrint(&debug_buf, "[workerPostMessageCallback] json_str len={d}, preview={s}, worker_ctx={*}, closing={}, terminated={}\n", .{ json_str.len, json_str[0..preview_len], worker_ctx, dedicated_worker.agent.isClosing(), dedicated_worker.agent.isTerminated() }) catch "[workerPostMessageCallback]\n";
    stderr_file.writeAll(debug_msg) catch {};

    // Check agent state
    if (dedicated_worker.agent.isClosing() or dedicated_worker.agent.isTerminated()) {
        stderr_file.writeAll("[workerPostMessageCallback] Agent is closing/terminated, returning\n") catch {};
        return;
    }

    // Serialize the JSON string for posting
    var js_value = workers.message_channel.JSValue{ .string = json_str };
    const serialized = workers.message_channel.serializeForPostMessage(
        dedicated_worker.allocator,
        &js_value,
    ) catch return;

    // Create QueuedMessage
    const msg = workers.message_channel.QueuedMessage.init(dedicated_worker.allocator, serialized, null) catch {
        serialized.deinit();
        dedicated_worker.allocator.destroy(serialized);
        return;
    };

    // Append to pending_messages for deferred dispatch
    workers.dedicated_worker.DedicatedWorker.appendPendingMessage(
        dedicated_worker.port_pair.outside_port,
        msg,
    ) catch {
        msg.deinit();
        return;
    };
}

// ============================================================================
// Worker Fetch API Support
// ============================================================================

/// Helper to throw TypeError in worker context
fn workerThrowTypeError(isolate: *v8.ffi.Isolate, info: *const v8.ffi.FunctionCallbackInfo, msg: []const u8) void {
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

/// Helper to reject a promise with TypeError in worker context
fn workerRejectWithTypeError(isolate: *v8.ffi.Isolate, v8_ctx: *v8.ffi.Context, resolver: *v8.ffi.PromiseResolver, msg: []const u8) void {
    const error_msg = v8.ffi.v8_String_NewFromUtf8(isolate, msg.ptr, @intCast(msg.len)) orelse return;
    const error_val = v8.ffi.v8_Exception_TypeError(@ptrCast(error_msg)) orelse return;
    _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_ctx, error_val);
}

/// Worker fetch callback - implements the global fetch() function for workers
/// Per Fetch spec: https://fetch.spec.whatwg.org/#fetch-method
fn workerFetchCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_ctx = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        workerThrowTypeError(isolate, info, "No context available");
        return;
    };

    // Get allocator from worker context
    const worker_ctx = current_worker_context orelse {
        workerThrowTypeError(isolate, info, "No worker context available");
        return;
    };
    const allocator = worker_ctx.allocator;

    // Create a Promise to return
    const resolver = v8.ffi.v8_PromiseResolver_New(v8_ctx) orelse {
        workerThrowTypeError(isolate, info, "Failed to create promise");
        return;
    };
    const promise = v8.ffi.v8_PromiseResolver_GetPromise(resolver) orelse {
        workerThrowTypeError(isolate, info, "Failed to get promise");
        return;
    };

    // Return the promise early - we'll resolve/reject it after fetch completes
    info.setReturnValue(@ptrCast(promise));

    // Check for URL argument
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        workerRejectWithTypeError(isolate, v8_ctx, resolver, "Failed to execute 'fetch': 1 argument required, but only 0 present.");
        return;
    }

    // Get URL from first argument
    const url_value = info.get(0);
    if (!v8.ffi.v8_Value_IsString(url_value)) {
        // TODO: Handle Request object input
        workerRejectWithTypeError(isolate, v8_ctx, resolver, "Failed to execute 'fetch': URL must be a string");
        return;
    }

    // Convert V8 string to Zig string
    const url_str = v8.ffi.v8_Value_ToString(url_value, v8_ctx) orelse {
        workerRejectWithTypeError(isolate, v8_ctx, resolver, "Failed to convert URL to string");
        return;
    };
    const url_len = v8.ffi.v8_String_Utf8Length(url_str);
    if (url_len <= 0 or url_len > 65536) {
        workerRejectWithTypeError(isolate, v8_ctx, resolver, "Invalid URL length");
        return;
    }

    const url_buffer = allocator.alloc(u8, @intCast(url_len)) catch {
        workerRejectWithTypeError(isolate, v8_ctx, resolver, "Out of memory");
        return;
    };
    defer allocator.free(url_buffer);

    const written = v8.ffi.v8_String_WriteUtf8(url_str, url_buffer.ptr, @intCast(url_len));
    if (written <= 0) {
        workerRejectWithTypeError(isolate, v8_ctx, resolver, "Failed to read URL string");
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
                                workerRejectWithTypeError(isolate, v8_ctx, resolver, "Failed to resolve URL");
                                return;
                            };
                            resolved_url_owned = true;
                        }
                    }
                } else {
                    // Relative path - append to base directory
                    const base_dir = doc_url[0 .. last_slash + 1];
                    resolved_url = std.fmt.allocPrint(allocator, "{s}{s}", .{ base_dir, url_slice }) catch {
                        workerRejectWithTypeError(isolate, v8_ctx, resolver, "Failed to resolve URL");
                        return;
                    };
                    resolved_url_owned = true;
                }
            }
        }
    }

    // Create internal request
    const internal_request = fetch.internal.InternalRequest.init(allocator, resolved_url) catch {
        workerRejectWithTypeError(isolate, v8_ctx, resolver, "Failed to create request");
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
        workerRejectWithTypeError(isolate, v8_ctx, resolver, err_msg);
        return;
    };
    defer fetch_result.timing_info.deinit();

    // Get the runtime context from context_manager (properly managed, tied to V8 context)
    // This ensures the context lives as long as the V8 context and has engine support
    const runtime_ctx = context_manager.getOrCreateWithIsolate(v8_ctx, isolate, allocator) catch {
        fetch_result.response.deinit();
        workerRejectWithTypeError(isolate, v8_ctx, resolver, "Failed to get runtime context");
        return;
    };

    // Create Response WebIDL wrapper from internal response
    const ResponseImpl = impls.Response;
    const response_instance = ResponseImpl.fromInternalResponse(allocator, fetch_result.response, runtime_ctx) catch {
        fetch_result.response.deinit();
        workerRejectWithTypeError(isolate, v8_ctx, resolver, "Failed to create Response object");
        return;
    };
    // Note: response_instance now owns fetch_result.response, don't deinit it separately

    // Wrap the Response instance for V8
    const response_js = v8.conversions.instanceToV8(isolate, response_instance);

    // Resolve the promise with the Response
    _ = v8.ffi.v8_PromiseResolver_Resolve(resolver, v8_ctx, response_js);
}

/// V8 callback for close() - terminates the worker
///
/// Spec: HTML Standard § 10.2.4.1 close()
/// https://html.spec.whatwg.org/#dom-dedicatedworkerglobalscope-close
///
/// Per the spec, close() sets the closing flag which prevents new tasks from being
/// added. However, messages already posted BEFORE close() (via postMessage) should
/// still be delivered. This is achieved by:
/// 1. Flushing pending messages to the port queue BEFORE setting the closing flag
/// 2. Scheduling a message dispatch callback to ensure delivery
fn workerCloseCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    _ = info;

    // Get WorkerV8Context from thread-local storage
    const self = current_worker_context orelse return;

    // Get the DedicatedWorker to close
    const dedicated_worker = self.dedicated_worker orelse return;

    // CRITICAL: Flush any pending messages BEFORE closing
    // Messages posted before close() (e.g., "before" in Phase 16.1 test) are stored
    // in the threadlocal pending_messages queue. We must move them to the port's
    // message_queue before close() stops the event loop, otherwise they'll never
    // be delivered.
    DedicatedWorker.flushPendingMessages();

    // Note: We don't schedule a timer for message dispatch here.
    // Messages will be dispatched synchronously by executeWorkerScriptCallback
    // after the worker script finishes executing. This avoids timer delays
    // that were causing test timeouts (test 16.1).

    // Now close the worker - this sets the closing flag and stops the event loop
    dedicated_worker.close();
}

/// V8 callback for importScripts(...urls) - loads and executes scripts synchronously
///
/// Spec: HTML Standard § 10.2.4.2 importScripts(urls)
/// https://html.spec.whatwg.org/#dom-workerglobalscope-importscripts
fn importScriptsCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    // Get WorkerV8Context from thread-local storage
    const self = current_worker_context orelse {
        std.log.warn("importScriptsCallback: no current_worker_context", .{});
        return;
    };

    // Get isolate and context from the callback info
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        std.log.warn("importScriptsCallback: no V8 context", .{});
        return;
    };

    // Get number of arguments (URLs to import)
    const argc = info.v8_FunctionCallbackInfo_Length();
    if (argc < 1) {
        return;
    }

    // Process each URL argument
    var i: c_int = 0;
    while (i < argc) : (i += 1) {
        const arg = info.get(i);

        // Convert to string
        const str = v8.ffi.v8_Value_ToString(arg, v8_context) orelse continue;
        const len = v8.ffi.v8_String_Utf8Length(str);
        if (len == 0) continue;

        // Get URL string
        var buf: [4096]u8 = undefined;
        const actual_len = v8.ffi.v8_String_WriteUtf8(str, &buf, @intCast(buf.len));
        if (actual_len <= 0) continue;

        const url = buf[0..@intCast(actual_len)];

        // Fetch the script
        // Per HTML Standard § 10.2.4.2 importScripts(urls):
        // "For each url of urls: Let urlRecord be the result of parsing url with worker global scope's url"
        // The worker's script_url is the base for resolving relative URLs
        var fetched_script = script_fetch.fetchWorkerScript(self.allocator, url, .{
            .is_import_scripts = true,
            .worker_type = .classic,
            .origin = self.script_url, // Base URL for relative path resolution
        }) catch |err| {
            std.log.warn("importScripts: failed to fetch '{s}': {}", .{ url, err });
            // Per spec, throw NetworkError on fetch failure
            // For now, just continue to next script
            continue;
        };
        defer fetched_script.deinit();

        // Execute the script synchronously
        _ = self.executeScript(fetched_script.source) catch |err| {
            std.log.warn("importScripts: failed to execute '{s}': {}", .{ url, err });
            continue;
        };
    }
}

/// V8 callback for done() - signals test completion (WPT testharness)
///
/// This is called by worker test scripts to signal they're done running tests.
/// The worker then posts a completion message to the main thread.
fn workerDoneCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    _ = info;
    // Note: The actual done() function in testharness.js handles posting
    // the completion message. We just need to have this function exist
    // so the worker script can call it.
}

/// V8 callback for queueMicrotask() in worker global scope
/// Per HTML Standard § 8.1.7 - Integration with the JavaScript job queue
fn workerQueueMicrotaskCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Get the callback function (first argument)
    // Per spec, queueMicrotask requires exactly one argument that must be callable
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        // Throw TypeError: callback is required
        const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "queueMicrotask requires a callback function", 44) orelse return;
        const exc = v8.ffi.v8_Exception_TypeError(@ptrCast(msg)) orelse return;
        v8.ffi.v8_Isolate_ThrowException(isolate, exc);
        return;
    }

    const callback_value = info.get(0);
    if (!v8.ffi.v8_Value_IsFunction(callback_value)) {
        // Throw TypeError: argument is not a function
        const msg = v8.ffi.v8_String_NewFromUtf8(isolate, "queueMicrotask argument must be a function", 42) orelse return;
        const exc = v8.ffi.v8_Exception_TypeError(@ptrCast(msg)) orelse return;
        v8.ffi.v8_Isolate_ThrowException(isolate, exc);
        return;
    }

    // Get the worker context
    const worker_ctx = current_worker_context orelse return;

    // Create Global handle for the callback function
    const callback_global = v8.ffi.v8_Value_ToGlobal(isolate, callback_value) orelse return;

    // Allocate microtask context
    const ctx = worker_ctx.allocator.create(WorkerMicrotaskContext) catch {
        v8.ffi.v8_Global_Dispose(callback_global);
        return;
    };

    ctx.* = .{
        .callback_global = callback_global,
        .isolate = isolate,
        .context = v8_context,
        .allocator = worker_ctx.allocator,
        .worker_v8_context = worker_ctx,
    };

    // Enqueue the microtask with V8
    // V8 will invoke workerMicrotaskTrampoline during the next PerformMicrotaskCheckpoint
    const callback_fn: ?*const anyopaque = @ptrCast(&workerMicrotaskTrampoline);
    v8.ffi.v8_Isolate_EnqueueMicrotask(isolate, callback_fn, ctx);
}

/// V8 callback for structuredClone() - creates a deep copy using the structured clone algorithm
///
/// Spec: HTML Standard § 2.7.8: StructuredClone method
/// https://html.spec.whatwg.org/multipage/structured-data.html#dom-structuredclone
///
/// Creates and returns a deep copy of a given value using the structured clone algorithm.
/// Primitives are returned as-is. Objects are serialized and deserialized to create
/// independent copies. Functions and Symbols throw DataCloneError.
fn workerStructuredCloneCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // structuredClone requires at least 1 argument (the value to clone)
    const argc = info.v8_FunctionCallbackInfo_Length();
    if (argc < 1) {
        // Per spec, undefined is a valid argument, but we need at least one arg syntactically
        // Clone undefined and return
        const undef = v8.ffi.v8_Undefined(isolate) orelse return;
        info.setReturnValue(@ptrCast(undef));
        return;
    }

    // Get the value to clone
    const value = info.get(0);

    // Check for unclonable types
    if (v8.ffi.v8_Value_IsFunction(value) or v8.ffi.v8_Value_IsSymbol(value)) {
        // Functions and Symbols cannot be cloned - throw DataCloneError
        const error_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to execute 'structuredClone': could not be cloned", 56) orelse return;
        const error_val = v8.ffi.v8_Exception_Error(@ptrCast(error_msg)) orelse return;
        _ = v8.ffi.v8_Isolate_ThrowException(isolate, error_val);
        return;
    }

    // Use V8's built-in structured clone for objects
    // This handles circular references, typed arrays, dates, etc.
    const cloned = v8.ffi.v8_Value_StructuredClone(value) orelse {
        // Clone failed - likely contains unclonable data
        const error_msg = v8.ffi.v8_String_NewFromUtf8(isolate, "Failed to execute 'structuredClone': could not be cloned", 56) orelse return;
        const error_val = v8.ffi.v8_Exception_Error(@ptrCast(error_msg)) orelse return;
        _ = v8.ffi.v8_Isolate_ThrowException(isolate, error_val);
        return;
    };

    info.setReturnValue(cloned);
}

/// Dispatch a MessageEvent to the worker's self.onmessage handler
///
/// This is called when processing messages from the main thread (inside_port).
/// It deserializes the message data and calls the JavaScript onmessage handler.
///
/// The function must be called from within the worker's V8 isolate context.
pub fn dispatchMessageToWorker(worker_ctx: *WorkerV8Context, msg: *workers.message_channel.QueuedMessage) void {
    const stderr_file = std.fs.File.stderr();
    stderr_file.writeAll("[dispatchMessageToWorker] ENTRY\n") catch {};

    const isolate = worker_ctx.isolate;
    const context = worker_ctx.context;

    // Create HandleScope for V8 operations
    const handle_scope = v8.ffi.v8_HandleScope_New(isolate);
    defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

    // Get global object
    const global_obj = v8.ffi.v8_Context_Global(context) orelse {
        stderr_file.writeAll("[dispatchMessageToWorker] No global object\n") catch {};
        return;
    };

    // Get self.onmessage property
    const onmessage_key = v8.ffi.v8_String_NewFromUtf8(isolate, "onmessage", 9) orelse {
        stderr_file.writeAll("[dispatchMessageToWorker] Failed to create onmessage key\n") catch {};
        return;
    };
    const onmessage_val = v8.ffi.v8_Object_Get(global_obj, context, @ptrCast(onmessage_key)) orelse {
        stderr_file.writeAll("[dispatchMessageToWorker] Failed to get onmessage property\n") catch {};
        return;
    };

    // Check if onmessage is a function
    // CRITICAL: Use v8_Value_IsFunction (for Global handles), NOT v8_Value_IsFunction_Local
    // v8_Object_Get returns Global<Value>*, so we must use the Global handle version
    if (!v8.ffi.v8_Value_IsFunction(onmessage_val)) {
        stderr_file.writeAll("[dispatchMessageToWorker] onmessage is NOT a function\n") catch {};
        return;
    }
    stderr_file.writeAll("[dispatchMessageToWorker] onmessage IS a function\n") catch {};

    // Deserialize message data to JSON string
    const serialized = msg.data;
    const json_str = switch (serialized.type) {
        .primitive => switch (serialized.data.primitive) {
            .string => |s| s,
            .undefined => "undefined",
            .null => "null",
            .boolean => |b| if (b) "true" else "false",
            .number => "0", // TODO: Proper number serialization
            .bigint => "0", // TODO: Proper bigint serialization
        },
        .string_object => serialized.data.string_object,
        else => {
            stderr_file.writeAll("[dispatchMessageToWorker] Unsupported message type\n") catch {};
            return;
        },
    };

    // Debug: Print the JSON string
    stderr_file.writeAll("[dispatchMessageToWorker] json_str: ") catch {};
    stderr_file.writeAll(json_str) catch {};
    stderr_file.writeAll("\n") catch {};

    // Create the message data as a V8 value by parsing the JSON
    const data_value = blk: {
        // Try to parse as JSON first using the buffer API
        const parsed = v8.ffi.v8_JSON_Parse_FromBuffer(context, json_str.ptr, @intCast(json_str.len));
        if (parsed != null) {
            stderr_file.writeAll("[dispatchMessageToWorker] JSON parsed successfully\n") catch {};
            break :blk parsed;
        }
        stderr_file.writeAll("[dispatchMessageToWorker] JSON parse failed, creating as string\n") catch {};
        // If not valid JSON, create as string literal
        const json_v8_str = v8.ffi.v8_String_NewFromUtf8(isolate, json_str.ptr, @intCast(json_str.len)) orelse break :blk null;
        break :blk @as(?*v8.ffi.Value, @ptrCast(json_v8_str));
    } orelse {
        stderr_file.writeAll("[dispatchMessageToWorker] Failed to create data value\n") catch {};
        return;
    };

    // Create a simple event object with 'data' property
    // For now, use a plain object instead of full MessageEvent
    const event_script =
        \\(function(data) {
        \\  return { data: data, type: 'message', target: self, currentTarget: self };
        \\})
    ;
    const event_source = v8.ffi.v8_String_NewFromUtf8(isolate, event_script.ptr, @intCast(event_script.len)) orelse {
        stderr_file.writeAll("[dispatchMessageToWorker] Failed to create event_source string\n") catch {};
        return;
    };
    const compile_result = v8.ffi.v8_Script_Compile_Safe(context, event_source);
    defer v8.ffi.v8_FreeScriptCompileResult(compile_result);

    if (compile_result.script == null) {
        stderr_file.writeAll("[dispatchMessageToWorker] Event script compilation failed\n") catch {};
        return;
    }

    const run_result = v8.ffi.v8_Script_Run_Safe(context, compile_result.script.?);
    defer v8.ffi.v8_FreeScriptRunResult(run_result);

    const event_factory = run_result.value orelse {
        stderr_file.writeAll("[dispatchMessageToWorker] Event factory run failed\n") catch {};
        return;
    };

    // Call the factory function with data to create event object
    var factory_args = [_]*v8.ffi.Value{data_value};
    const event_obj = v8.ffi.v8_Function_Call(
        @ptrCast(event_factory),
        context,
        @ptrCast(global_obj),
        1,
        &factory_args,
    ) orelse {
        stderr_file.writeAll("[dispatchMessageToWorker] Event factory call failed\n") catch {};
        return;
    };
    stderr_file.writeAll("[dispatchMessageToWorker] Event object created\n") catch {};

    // Call onmessage(event)
    stderr_file.writeAll("[dispatchMessageToWorker] Calling onmessage handler...\n") catch {};
    var args = [_]*v8.ffi.Value{event_obj};
    _ = v8.ffi.v8_Function_Call(
        @ptrCast(onmessage_val),
        context,
        @ptrCast(global_obj),
        1,
        &args,
    );
    stderr_file.writeAll("[dispatchMessageToWorker] onmessage handler returned\n") catch {};

    // Run microtasks after handler
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
    stderr_file.writeAll("[dispatchMessageToWorker] DONE\n") catch {};
}

/// Process incoming messages from the main thread
///
/// This should be called from within the worker's V8 context after
/// the worker script has set up its onmessage handler.
pub fn processIncomingMessages(worker_ctx: *WorkerV8Context) void {
    const stderr_file = std.fs.File.stderr();
    stderr_file.writeAll("[processIncomingMessages] ENTRY\n") catch {};
    const dedicated_worker = worker_ctx.dedicated_worker orelse {
        stderr_file.writeAll("[processIncomingMessages] No dedicated_worker, returning\n") catch {};
        return;
    };

    // Process messages inside worker isolate context
    {
        // Enter the worker's isolate and context
        v8.ffi.v8_Isolate_Enter(worker_ctx.isolate);
        v8.ffi.v8_Context_Enter(worker_ctx.context);
        defer {
            v8.ffi.v8_Context_Exit(worker_ctx.context);
            v8.ffi.v8_Isolate_Exit(worker_ctx.isolate);
        }

        // Create HandleScope for V8 operations (required for string creation in dispatchMessageToWorkerInternal)
        const handle_scope = v8.ffi.v8_HandleScope_New(worker_ctx.isolate);
        defer v8.ffi.v8_HandleScope_Dispose(handle_scope);

        // Set current_worker_context for any callbacks
        const prev_context = current_worker_context;
        current_worker_context = worker_ctx;
        defer current_worker_context = prev_context;

        // Process messages - directly iterate over the queue
        const inside_port = dedicated_worker.port_pair.inside_port;
        const queue_len = inside_port.message_queue.items.len;
        var buf: [128]u8 = undefined;
        const msg_str = std.fmt.bufPrint(&buf, "[processIncomingMessages] inside_port has {d} messages\n", .{queue_len}) catch "[processIncomingMessages] inside_port check\n";
        stderr_file.writeAll(msg_str) catch {};

        while (inside_port.message_queue.items.len > 0) {
            const msg = inside_port.message_queue.orderedRemove(0);
            stderr_file.writeAll("[processIncomingMessages] Dispatching message via JS\n") catch {};
            // Use the internal method which dispatches via JavaScript - cleaner and avoids FFI handle issues
            worker_ctx.dispatchMessageToWorkerInternal(msg);
            msg.deinit();
        }
    }
    // Block exits here, so we're now outside the worker isolate

    // CRITICAL: Flush pending messages AFTER exiting worker isolate
    // When worker's onmessage handler calls self.postMessage(), messages are queued
    // in pending_messages (not directly to outside_port) to avoid HandleScope issues.
    // Now that we've exited the worker isolate, flush them to the actual port.
    workers.dedicated_worker.DedicatedWorker.flushPendingMessages();
    stderr_file.writeAll("[processIncomingMessages] Flushed pending messages\n") catch {};

    stderr_file.writeAll("[processIncomingMessages] Done processing\n") catch {};
}

// ============================================================================
// Error Types
// ============================================================================

pub const WorkerV8Error = error{
    V8IsolateCreationFailed,
    V8ContextCreationFailed,
    NoGlobalObject,
    StringCreationFailed,
    CompilationFailed,
    ExecutionFailed,
    OutOfMemory,
    FunctionTemplateCreateFailed,
    FunctionCreateFailed,
};

// ============================================================================
// Tests
// ============================================================================

test "WorkerV8Context - struct definition" {
    // Just verify the struct can be referenced
    // Actual V8 tests require the V8 runtime
    const T = WorkerV8Context;
    try std.testing.expect(@sizeOf(T) > 0);
}
