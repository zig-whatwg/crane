//! Implementation for Worker interface
//!
//! Spec: HTML Standard § 10.2.3 Dedicated workers and the Worker interface
//! https://html.spec.whatwg.org/#dedicated-workers-and-the-worker-interface
//!
//! This implementation bridges the WebIDL Worker interface to the underlying
//! DedicatedWorker implementation in src/html/workers/.
//!
//! ## Message Passing Architecture
//!
//! When `worker.postMessage(data)` is called from JS:
//! 1. call_postMessage serializes `data` using structured clone
//! 2. Message is queued to DedicatedWorker's outside_port
//! 3. outside_port delivers to entangled inside_port (worker side)
//! 4. Worker's V8 context receives MessageEvent
//!
//! When worker calls `self.postMessage(data)`:
//! 1. Worker serializes `data` using structured clone
//! 2. Message is queued to inside_port
//! 3. inside_port delivers to entangled outside_port (main thread)
//! 4. handleMessageFromWorker creates MessageEvent
//! 5. onmessage handler is invoked with MessageEvent

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const Worker = interfaces.Worker;
const MessageEvent = interfaces.MessageEvent;
const EventTarget = interfaces.EventTarget;

// Import parent class implementation for proper initialization chain
const EventTargetImpl = @import("EventTarget.zig");

// Import workers infrastructure
const html_core = @import("html_core");
const workers = html_core.workers;
const DedicatedWorker = workers.DedicatedWorker;
const WorkerOptions = workers.WorkerOptions;
const WorkerType = workers.WorkerType;
const RequestCredentials = workers.RequestCredentials;
const message_channel = workers.message_channel;
const WorkerErrorEvent = workers.worker_error.WorkerErrorEvent;
const QueuedMessage = message_channel.QueuedMessage;
const SerializedValue = message_channel.SerializedValue;
const WorkerContext = workers.WorkerContext;

// Import html module for WorkerV8Context (has interface access, unlike html_core)
const html_full = @import("html");
const WorkerV8Context = html_full.WorkerV8Context;

// Import structured clone for message passing
const structured_clone = html_core.structured_clone;
const V8SerializedData = structured_clone.types.V8SerializedData;
const TransferredArrayBufferData = structured_clone.types.TransferredArrayBufferData;
const TransferredPortData = structured_clone.types.TransferredPortData;

// Import MessagePort impl for port transfer
const MessagePortImpl = @import("MessagePort.zig");

// Import MessagePort for communication
const message_port_internal = @import("streams_internal");
const InternalMessagePort = message_port_internal.MessagePort;

// Import platform for TimerBackend (used to create DedicatedWorker)
const platform = @import("platform");

// Import V8 engine for callback invocation
const v8_engine = @import("v8");
const template_registry = v8_engine.template_registry;

// Import event loop for task scheduling (message dispatch)
const event_loop_mod = @import("streams_event_loop");

pub const State = Worker.State;

pub const ImplError = error{
    NotImplemented,
    WorkerCreationFailed,
    InvalidURL,
    OutOfMemory,
    PostMessageFailed,
};

/// Internal state for Worker implementation
///
/// Contains the backing DedicatedWorker from src/html/workers/
/// and the entangled MessagePort pair for communication.
///
/// Note: The DedicatedWorker requires a TimerBackend which comes from
/// the platform layer. The WebIDL impl stores worker configuration,
/// and actual worker lifecycle is managed when platform is available.
pub const InternalState = struct {
    /// The underlying dedicated worker implementation (optional - created when platform is set)
    dedicated_worker: ?*DedicatedWorker = null,

    /// V8 context for worker execution (created when DedicatedWorker starts)
    v8_context: ?*WorkerV8Context = null,

    /// Outside MessagePort (exposed to the caller)
    outside_port: ?*runtime.Instance = null,

    /// Worker configuration
    script_url: []const u8,
    name: []const u8,
    worker_type: WorkerType,
    credentials: RequestCredentials,

    /// Whether the worker has been terminated
    terminated: bool = false,

    /// Whether the worker script has been evaluated
    /// Per Chromium's DedicatedWorkerMessagingProxy::was_script_evaluated_ pattern:
    /// Messages must not be dispatched until the script finishes executing.
    script_evaluated: bool = false,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    /// Reference to the Worker instance (for message handling)
    worker_instance: ?*runtime.Instance = null,

    /// Runtime context for creating MessageEvent
    ctx: ?runtime.Context = null,

    /// V8 isolate for callback invocation
    isolate: ?*v8_engine.ffi.Isolate = null,

    /// Event handler GlobalHandles (stored as V8 Global handles for proper lifecycle)
    /// These are extracted from tagged pointers when set via the WebIDL setters.
    onmessage_handle: v8_engine.OptionalGlobalHandle = null,
    onerror_handle: v8_engine.OptionalGlobalHandle = null,
    onmessageerror_handle: v8_engine.OptionalGlobalHandle = null,

    /// Pending script source to execute (deferred from constructor)
    /// This is set during constructor and executed via timer callback
    pending_script: ?[]const u8 = null,

    /// Pending messages to send to worker (before DedicatedWorker is created)
    /// Messages are queued here if postMessage is called before worker initialization completes.
    /// Once the DedicatedWorker is ready, these are flushed to the inside port.
    pending_outgoing_messages: std.ArrayList(*workers.message_channel.SerializedValue),

    pub fn deinit(self: *InternalState) void {
        // Clean up pending outgoing messages
        for (self.pending_outgoing_messages.items) |msg| {
            msg.deinit();
            self.allocator.destroy(msg);
        }
        self.pending_outgoing_messages.deinit(self.allocator);
        // Dispose V8 Global handles to prevent memory leaks
        v8_engine.disposeOptionalGlobalHandle(&self.onmessage_handle);
        v8_engine.disposeOptionalGlobalHandle(&self.onerror_handle);
        v8_engine.disposeOptionalGlobalHandle(&self.onmessageerror_handle);

        // Clean up V8 context first (it uses the dedicated_worker's WorkerContext)
        if (self.v8_context) |v8_ctx| {
            v8_ctx.deinit();
        }
        if (self.dedicated_worker) |worker| {
            worker.deinit();
        }
        self.allocator.free(self.script_url);
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }
        // Free pending script if not yet executed
        if (self.pending_script) |script| {
            self.allocator.free(script);
        }
    }
};

/// Initialize instance (creates the instance)
/// IMPORTANT: Worker extends EventTarget, so we must chain to EventTarget.init()
/// to properly set up the event listener infrastructure needed for addEventListener.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (EventTarget) to set up event listener state
    const instance = try EventTargetImpl.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
/// IMPORTANT: Must chain to EventTarget.deinit() through interface (not impl directly)
/// to clean up event listener state.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    // Chain to parent class through interface for proper deinit
    EventTarget.deinit(instance);
}

/// Constructor implementation
///
/// Spec: HTML Standard § 10.2.3.1 The Worker() constructor
/// https://html.spec.whatwg.org/#dom-worker
///
/// This is called when the interface is constructed from JavaScript:
/// new Worker(scriptURL, options)
pub fn call_constructor(ctx: runtime.Context, scriptURL: runtime.DOMString, options: webidl.Opt(dictionaries.WorkerOptions)) !*runtime.Instance {

    // NOTE: We rely on the persistent HandleScope from BrowserContext.
    // Creating a local HandleScope here and disposing it at the end of the constructor
    // would leave V8 without a HandleScope for subsequent JavaScript execution.
    // The persistent HandleScope in BrowserContext stays active for the entire test.

    // Create instance through init()
    const instance = try init(ctx.allocator, State, &Worker.vtable, ctx);
    errdefer deinit(instance);

    // Parse options - use defaults for type/credentials since dictionary has opaque enum pointers
    const worker_type = WorkerType.classic;
    const credentials = RequestCredentials.same_origin;
    var name: []const u8 = "";

    if (options.wasPassed()) {
        const opts = options.getValue();
        // Note: opts.type and opts.credentials are ?*const anyopaque (opaque enum pointers)
        // The dictionary codegen doesn't provide typed enum access yet.
        // For now, we use default values (classic, same_origin).
        // TODO: When dictionary codegen supports typed enums, parse these:
        // - type: "classic" | "module" -> WorkerType
        // - credentials: "omit" | "same-origin" | "include" -> RequestCredentials
        _ = opts.type; // Acknowledge but skip (uses default: classic)
        _ = opts.credentials; // Acknowledge but skip (uses default: same_origin)

        // Parse name if present (this is a DOMString, not an enum)
        if (opts.name) |n| {
            name = n.asSlice();
        }
    }

    // Copy the script URL
    const url_copy = try ctx.allocator.dupe(u8, scriptURL.asSlice());
    errdefer ctx.allocator.free(url_copy);

    // Copy the name if present
    const name_copy = if (name.len > 0)
        try ctx.allocator.dupe(u8, name)
    else
        "";
    errdefer if (name_copy.len > 0) ctx.allocator.free(name_copy);

    // Create internal state
    const internal_state = try ctx.allocator.create(InternalState);
    errdefer ctx.allocator.destroy(internal_state);

    // Get the current isolate - don't cast ctx.engine_ctx as it stores the V8 Context, not Isolate
    const current_isolate = v8_engine.ffi.v8_Isolate_GetCurrent();

    internal_state.* = .{
        .dedicated_worker = null,
        .script_url = url_copy,
        .name = name_copy,
        .worker_type = worker_type,
        .credentials = credentials,
        .allocator = ctx.allocator,
        .worker_instance = instance,
        .ctx = ctx,
        .isolate = current_isolate,
        .pending_outgoing_messages = .{},
    };

    // Store internal state in instance
    var state = instance.getState(State);
    state.own._internal = internal_state;

    // CRITICAL: Defer ALL worker creation to a task/timer callback!
    // For nested workers (Worker created from within another Worker),
    // entering/exiting the worker isolate during the constructor corrupts
    // the calling isolate's HandleScope state, causing V8 crashes.
    //
    // Solution: The constructor only stores parameters and schedules
    // the actual worker creation for later via queueTask or setTimeout.
    // This runs after:
    // 1. The constructor returns and V8 wraps the instance
    // 2. The calling script finishes
    // 3. The event loop runs the scheduled task
    //
    // Per HTML Standard § 10.2.5 "Run a worker": worker creation is asynchronous
    //
    // CRITICAL: Use queueTask instead of setTimeout to guarantee task ordering.
    // Per research on Chromium's DedicatedWorkerMessagingProxy and V8 event loop:
    // - Tasks queued via queueTask are processed BEFORE libuv timers
    // - This ensures worker init happens before test timeout timers
    // - Using setTimeout(1ms) creates a race condition with test timeouts
    if (ctx.getOptionalEventLoop()) |event_loop| {
        event_loop.queueTask(event_loop_mod.Task{
            .callback = initializeWorkerCallback,
            .context = instance,
        });
    } else {
        // Fallback: try timer if no event loop available
        // For nested workers, ctx.timer may be null (context lookup may fail to find
        // the registered worker context with timer). In this case, we fall back to
        // the thread-local timer which was set when the parent worker's context was
        // set up. This timer remains available during the parent worker's script
        // execution, which is when nested workers are created.
        const timer = ctx.timer orelse WorkerV8Context.getTimerInterface();

        if (timer) |t| {
            // Use 1ms delay instead of 0 to ensure the callback fires in a
            // FUTURE event loop iteration, not the current one. With 0 delay,
            // the callback might fire immediately when the event loop is polled
            // during the parent worker's script execution, causing HandleScope
            // corruption when we enter the nested worker's isolate.
            _ = t.setTimeout(1, initializeWorkerCallback, instance);
        } else {
            // No timer available - fall back to synchronous initialization
            // WARNING: This may cause crashes for nested workers
            std.log.warn("Worker: no timer available, using synchronous initialization", .{});
            initializeWorkerSync(internal_state, ctx);
        }
    }

    return instance;
}

/// Getter for onerror
///
/// Spec: HTML Standard § 10.2.3
/// Event handler for error events on the worker.
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onerror;
}

/// Getter for onmessage
///
/// Spec: HTML Standard § 10.2.3
/// Event handler for message events from the worker.
pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onmessage;
}

/// Getter for onmessageerror
///
/// Spec: HTML Standard § 10.2.3
/// Event handler for messageerror events.
pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onmessageerror;
}

/// Extract GlobalHandle from a tagged callback pointer (from V8 conversion).
/// The V8 conversions layer creates Global handles and tags the pointers.
fn extractEventHandler(handler: ?*const anyopaque) v8_engine.OptionalGlobalHandle {
    if (handler) |ptr| {
        const untagged = v8_engine.pointer_tag.untagPointer(ptr);
        if (untagged.tag == .global_handle or untagged.tag == .untagged) {
            return v8_engine.GlobalHandle{ .ptr = @ptrCast(@alignCast(untagged.ptr)) };
        }
    }
    return null;
}

/// Get internal state from instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return if (state.own._internal) |internal| @constCast(internal) else null;
}

/// Setter for onerror
/// Extracts GlobalHandle from the tagged pointer passed from V8.
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onerror = value;

    // Also store as GlobalHandle in internal state for proper V8 invocation
    if (getInternal(instance)) |internal| {
        v8_engine.disposeOptionalGlobalHandle(&internal.onerror_handle);
        // Properly unwrap the optional before casting to extract the tagged pointer
        if (value) |v| {
            const casted: *const anyopaque = @ptrCast(v);
            internal.onerror_handle = extractEventHandler(casted);
        } else {
            internal.onerror_handle = null;
        }
    }
}

/// Setter for onmessage
/// Extracts GlobalHandle from the tagged pointer passed from V8.
///
/// When onmessage is set, we also process any queued messages. This handles the
/// common pattern where:
/// 1. Worker constructor executes the worker script (which posts messages)
/// 2. JavaScript continues and sets worker.onmessage
/// 3. Messages should now be delivered
///
/// Per HTML spec, messages should be delivered asynchronously via the event loop.
/// However, for practical purposes (especially WPT tests), processing messages
/// when the handler is set achieves the correct observable behavior - messages
/// are delivered after the handler is ready.
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onmessage = value;

    // DEBUG - only log for Worker instances (not Window.onmessage)
    const stderr_file = std.fs.File.stderr();

    // Also store as GlobalHandle in internal state for proper V8 invocation
    if (getInternal(instance)) |internal| {
        v8_engine.disposeOptionalGlobalHandle(&internal.onmessage_handle);
        // Properly unwrap the optional before casting to extract the tagged pointer
        internal.onmessage_handle = if (value) |v| extractEventHandler(@ptrCast(v)) else null;

        var debug_buf: [256]u8 = undefined;
        const debug_msg = std.fmt.bufPrint(&debug_buf, "[Worker.set_onmessage] instance={*}, handler_set={}, dedicated_worker={?*}\n", .{ instance, internal.onmessage_handle != null, internal.dedicated_worker }) catch "[Worker.set_onmessage]\n";
        stderr_file.writeAll(debug_msg) catch {};

        // Process any messages that were queued before the handler was set
        // This ensures messages posted by the worker during script execution
        // are delivered now that there's a handler to receive them.
        if (internal.dedicated_worker) |dedicated_worker| {
            const queue_len = dedicated_worker.port_pair.outside_port.message_queue.items.len;
            var queue_msg_buf: [128]u8 = undefined;
            const queue_msg = std.fmt.bufPrint(&queue_msg_buf, "[Worker.set_onmessage] worker={*}, queue_len={d}\n", .{ dedicated_worker, queue_len }) catch "[Worker.set_onmessage] queue\n";
            stderr_file.writeAll(queue_msg) catch {};
            dedicated_worker.processQueuedMessages();
        } else {
            stderr_file.writeAll("[Worker.set_onmessage] WARN: dedicated_worker is NULL! Cannot process queued messages.\n") catch {};
        }
    }
}

/// Setter for onmessageerror
/// Extracts GlobalHandle from the tagged pointer passed from V8.
pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onmessageerror = value;

    // Also store as GlobalHandle in internal state for proper V8 invocation
    if (getInternal(instance)) |internal| {
        v8_engine.disposeOptionalGlobalHandle(&internal.onmessageerror_handle);
        // Properly unwrap the optional before casting to extract the tagged pointer
        internal.onmessageerror_handle = if (value) |v| extractEventHandler(@ptrCast(v)) else null;
    }
}

/// Timer callback for initializing the worker (deferred from constructor)
///
/// CRITICAL: ALL worker creation is deferred to this callback for nested workers.
/// Entering/exiting the worker isolate during a constructor disrupts the calling
/// isolate's HandleScope state, causing V8 crashes.
///
/// This callback does all the heavy work:
/// 1. Creates DedicatedWorker with timer backend
/// 2. Fetches and resolves the script URL
/// 3. Creates WorkerV8Context (new isolate)
/// 4. Sets up DedicatedWorkerGlobalScope
/// 5. Schedules script execution
fn initializeWorkerCallback(user_data: ?*anyopaque) void {
    const instance: *runtime.Instance = @ptrCast(@alignCast(user_data orelse return));
    const internal = getInternal(instance) orelse return;

    // Get the stored context - we need it for timer operations
    const ctx = internal.ctx orelse {
        std.log.warn("Worker: no runtime context available for deferred initialization", .{});
        return;
    };
    initializeWorkerSync(internal, ctx);
}

/// Initialize worker synchronously (internal helper)
/// Called from either initializeWorkerCallback or synchronous fallback
///
/// This does all the heavy work that was previously in the constructor:
/// - Creates DedicatedWorker
/// - Fetches script
/// - Creates V8 context (enters/exits worker isolate)
/// - Sets up global scope
/// - Schedules script execution
fn initializeWorkerSync(internal: *InternalState, ctx: runtime.Context) void {
    const allocator = internal.allocator;
    const url = internal.script_url;
    const name = internal.name;
    const worker_type = internal.worker_type;
    const credentials = internal.credentials;

    // Try to create the DedicatedWorker using the global timer backend
    const timer_backend = platform.getDefaultTimerBackend(allocator) catch |err| {
        std.log.warn("TimerBackend not available: {}, worker will not start", .{err});
        return;
    };

    const dedicated_worker = DedicatedWorker.init(
        allocator,
        timer_backend,
        url,
        .{
            .name = name,
            .worker_type = worker_type,
            .credentials = credentials,
        },
    ) catch |err| {
        std.log.warn("Failed to create DedicatedWorker: {}", .{err});
        return;
    };
    internal.dedicated_worker = dedicated_worker;

    // Store reference to Worker instance for message callbacks
    dedicated_worker.setUserData(internal.worker_instance);

    // Set up message handler on outside port to receive messages from worker
    dedicated_worker.setOnMessage(handleMessageFromWorkerCallback);

    // Set up error handler to receive errors from worker
    dedicated_worker.setParentErrorCallback(handleErrorFromWorkerCallback);

    // Enable message dispatch on outside port
    dedicated_worker.startMessageQueue();

    // NOTE: Pending messages are NOT flushed here. Per Chromium's implementation,
    // messages must be held until the worker script finishes evaluating.
    // See DedicatedWorkerMessagingProxy::was_script_evaluated_ flag.
    // The flush happens in executeWorkerScriptCallback AFTER script execution.

    // Fetch the worker script
    const fetched_script = workers.fetchWorkerScript(allocator, url, .{
        .worker_type = worker_type,
        .origin = null,
    }) catch |err| {
        std.log.warn("Failed to fetch worker script: {}", .{err});
        return;
    };

    // Create V8 context for worker execution
    const v8_context = WorkerV8Context.init(
        allocator,
        fetched_script.final_url,
        worker_type,
    ) catch |err| {
        std.log.warn("Failed to create WorkerV8Context: {}", .{err});
        @constCast(&fetched_script).deinit();
        return;
    };
    internal.v8_context = v8_context;

    // Create the WorkerContext
    dedicated_worker.startWithContext() catch |err| {
        std.log.warn("Failed to start worker context: {}", .{err});
        @constCast(&fetched_script).deinit();
        return;
    };

    // Wire up the V8 context to the WorkerAgent's WorkerContext
    if (dedicated_worker.agent.worker_context) |worker_ctx| {
        worker_ctx.setEngineContext(v8_context.getEngineContext(), v8_context.getCallbacks());
    } else {
        std.log.warn("WorkerContext not created after startWithContext", .{});
        @constCast(&fetched_script).deinit();
        return;
    }

    // Set up the timer interface for worker timers
    if (ctx.timer) |timer| {
        WorkerV8Context.setTimerInterface(timer);
    }

    // Set up DedicatedWorkerGlobalScope with proper globals
    v8_context.setupWorkerGlobalScope(dedicated_worker) catch |err| {
        std.log.warn("Failed to set up worker global scope: {}", .{err});
        @constCast(&fetched_script).deinit();
        return;
    };

    // Start the worker's message queue
    dedicated_worker.startWorkerMessageQueue();

    // Store the fetched script source for execution
    const script_source_copy = allocator.dupe(u8, fetched_script.source) catch |err| {
        std.log.warn("Failed to copy worker script source: {}", .{err});
        @constCast(&fetched_script).deinit();
        return;
    };
    internal.pending_script = script_source_copy;

    // Clean up fetched script metadata
    @constCast(&fetched_script).deinit();

    // Execute worker script SYNCHRONOUSLY to prevent race with cleanup.
    //
    // The issue: If we defer script execution to a timer, test cleanup can call
    // worker.terminate() BEFORE the script runs. This happens because:
    // 1. Constructor schedules 1ms timer for script execution
    // 2. Test harness checks all_done() after window.load (0ms timer)
    // 3. If all_done() returns true, cleanup runs and terminates workers
    // 4. 1ms timer fires but workers are already terminated
    //
    // The fix: Execute script synchronously during construction. This ensures
    // the script runs before any cleanup can interfere.
    //
    // Per Chromium's DedicatedWorkerMessagingProxy pattern:
    // - Script executes synchronously
    // - Messages are queued in pending_outgoing_messages (not dispatched yet)
    // - script_evaluated flag is set after script completes
    // - Message dispatch happens in a deferred callback (for handler setup)
    _ = executeWorkerScriptSync(internal);

    // CRITICAL: Mark script as evaluated AFTER execution completes.
    // This flag gates message dispatch in postMessage() - without it, messages
    // posted before the script runs would be dispatched to a non-existent handler.
    internal.script_evaluated = true;

    // Schedule message dispatch to allow JavaScript to set up worker.onmessage
    // handlers before messages are dispatched. This is the deferred part.
    //
    // CRITICAL: Use queueTask instead of setTimeout to guarantee task ordering.
    // Per research on Chromium's DedicatedWorkerMessagingProxy and V8 event loop:
    // - Tasks queued via queueTask are processed BEFORE libuv timers
    // - This ensures message dispatch happens before test timeout timers
    // - Using setTimeout(1ms) creates a race condition with test timeouts
    if (ctx.getOptionalEventLoop()) |event_loop| {
        event_loop.queueTask(event_loop_mod.Task{
            .callback = executeWorkerMessageDispatchCallback,
            .context = internal.worker_instance,
        });
    } else if (ctx.timer) |timer| {
        // Fallback to timer if no event loop available
        _ = timer.setTimeout(1, executeWorkerMessageDispatchCallback, internal.worker_instance);
    } else {
        // No timer or event loop - dispatch messages synchronously (handlers may not be set up)
        dispatchWorkerMessages(internal);
    }
}

/// Timer callback for executing the worker script (deferred from constructor)
///
/// CRITICAL: Worker script execution is deferred to this callback to avoid
/// HandleScope corruption. Entering/exiting the worker isolate during the
/// constructor disrupts the main isolate's HandleScope state.
///
/// This callback runs after:
/// 1. The constructor returns and V8 has wrapped the instance
/// 2. JavaScript continues (fetch_tests_from_worker sets up handlers)
/// 3. The event loop runs this scheduled task
fn executeWorkerScriptCallback(user_data: ?*anyopaque) void {
    const instance: *runtime.Instance = @ptrCast(@alignCast(user_data orelse return));
    const internal = getInternal(instance) orelse return;

    // Execute worker script.
    //
    // Timeline (per Chromium's DedicatedWorkerMessagingProxy):
    // 1. new Worker(...) - constructor returns, fetch_tests_from_worker sets up handlers
    // 2. JavaScript calls worker.postMessage() - messages queued in pending_outgoing_messages
    // 3. setTimeout(0, executeWorkerScriptCallback) fires (we're here)
    // 4. Worker script runs, sets self.onmessage handler
    // 5. Script evaluation complete - NOW flush pending messages (was_script_evaluated_ = true)
    // 6. Messages dispatched to worker's onmessage handler
    _ = executeWorkerScriptSync(internal);

    // CRITICAL: Mark script as evaluated AFTER execution completes.
    // This flag gates message dispatch in postMessage() - without it, messages
    // posted before the script runs would be dispatched to a non-existent handler.
    internal.script_evaluated = true;

    // CRITICAL: Flush pending messages AFTER script evaluation (per Chromium pattern).
    // Before this point, was_script_evaluated_ was effectively false.
    // Now the worker's onmessage handler is set up and ready to receive messages.
    const dedicated_worker = internal.dedicated_worker orelse return;
    const pending_count = internal.pending_outgoing_messages.items.len;
    if (pending_count > 0) {
        std.log.debug("[Worker] Flushing {d} pending messages after script eval", .{pending_count});
        for (internal.pending_outgoing_messages.items) |serialized| {
            dedicated_worker.port_pair.outside_port.postMessage(serialized, null) catch |err| {
                std.log.warn("[Worker] Failed to flush pending message: {}", .{err});
                serialized.deinit();
                internal.allocator.destroy(serialized);
                continue;
            };
        }
        internal.pending_outgoing_messages.clearRetainingCapacity();
        std.log.debug("[Worker] inside_port queue has {d} messages", .{dedicated_worker.port_pair.inside_port.message_queue.items.len});
    }

    // Now process the messages in the worker's V8 context.
    // The messages are in inside_port.message_queue (via port entanglement).
    if (internal.v8_context) |v8_ctx| {
        std.log.debug("[Worker] Processing incoming messages in worker V8 context", .{});
        html_full.worker_v8_context.processIncomingMessages(v8_ctx);
        std.log.debug("[Worker] Done processing incoming messages", .{});
    }

    // Check if worker sent any messages back and dispatch them to main thread
    const outside_queue_len = dedicated_worker.port_pair.outside_port.message_queue.items.len;
    const has_messages = outside_queue_len > 0;

    // DEBUG: Write to stderr to see if messages are in the queue
    const stderr_file = std.fs.File.stderr();
    var debug_buf: [256]u8 = undefined;
    const debug_msg = std.fmt.bufPrint(&debug_buf, "[executeWorkerScriptCallback] outside_port queue len={d}, has_messages={}\n", .{ outside_queue_len, has_messages }) catch "[executeWorkerScriptCallback] check\n";
    stderr_file.writeAll(debug_msg) catch {};

    // Dispatch worker→main messages synchronously.
    // Although worker script execution enters/exits the worker isolate (which could
    // corrupt the outer HandleScope), dispatchMessageEvent creates its own fresh
    // HandleScope for V8 operations. This is safe because:
    // 1. We've exited the worker isolate and are back in the main isolate
    // 2. dispatchMessageEvent creates a new HandleScope before any V8 operations
    // 3. This avoids timer scheduling delays that cause test timeouts
    if (has_messages) {
        stderr_file.writeAll("[executeWorkerScriptCallback] Calling processQueuedMessages\n") catch {};
        dedicated_worker.processQueuedMessages();

        // CRITICAL: Message handlers may have posted NEW messages via self.postMessage().
        // For nested workers, the outer worker's onmessage handler calling self.postMessage()
        // will queue messages in pending_messages. These may go to DIFFERENT worker ports!
        //
        // Example flow:
        // 1. Inner worker: self.postMessage("from inner") → queued in pending_messages
        // 2. flushPendingMessages() → moved to inner worker's outside_port.message_queue
        // 3. processQueuedMessages() → dispatches to outer worker's onmessage
        // 4. Outer worker's onmessage: self.postMessage("outer received: ...")
        //    → queued in pending_messages for OUTER worker's outside_port
        // 5. We need to flush and process ALL affected ports!
        processAllPendingMessages(internal);
    }
}

/// Timer callback for dispatching worker messages after script execution.
///
/// This callback runs after the constructor returns, allowing JavaScript to
/// set up worker.onmessage handlers before messages are dispatched.
///
/// Timeline:
/// 1. new Worker(...) - script executes synchronously during construction
/// 2. Constructor returns, JavaScript sets up worker.onmessage
/// 3. setTimeout(1, executeWorkerMessageDispatchCallback) fires (we're here)
/// 4. Messages dispatched to worker's onmessage handler
fn executeWorkerMessageDispatchCallback(user_data: ?*anyopaque) void {
    const instance: *runtime.Instance = @ptrCast(@alignCast(user_data orelse return));
    const internal = getInternal(instance) orelse return;
    dispatchWorkerMessages(internal);
}

/// Dispatch worker messages to main thread handlers.
/// This is called either from the timer callback or synchronously as fallback.
fn dispatchWorkerMessages(internal: *InternalState) void {
    const dedicated_worker = internal.dedicated_worker orelse return;

    // Flush pending messages to the inside port for worker to receive
    const pending_count = internal.pending_outgoing_messages.items.len;
    if (pending_count > 0) {
        std.log.debug("[Worker] Flushing {d} pending messages after script eval", .{pending_count});
        for (internal.pending_outgoing_messages.items) |serialized| {
            dedicated_worker.port_pair.outside_port.postMessage(serialized, null) catch |err| {
                std.log.warn("[Worker] Failed to flush pending message: {}", .{err});
                serialized.deinit();
                internal.allocator.destroy(serialized);
                continue;
            };
        }
        internal.pending_outgoing_messages.clearRetainingCapacity();
        std.log.debug("[Worker] inside_port queue has {d} messages", .{dedicated_worker.port_pair.inside_port.message_queue.items.len});
    }

    // Process messages in the worker's V8 context
    if (internal.v8_context) |v8_ctx| {
        std.log.debug("[Worker] Processing incoming messages in worker V8 context", .{});
        html_full.worker_v8_context.processIncomingMessages(v8_ctx);
        std.log.debug("[Worker] Done processing incoming messages", .{});
    }

    // CRITICAL: Flush messages from threadlocal pending_messages to port queues.
    // Worker's self.postMessage() adds messages to pending_messages, not directly
    // to outside_port.message_queue. This flush moves them to the actual port.
    DedicatedWorker.flushPendingMessages();

    // Check if worker sent any messages back and dispatch them to main thread
    const outside_queue_len = dedicated_worker.port_pair.outside_port.message_queue.items.len;
    const has_messages = outside_queue_len > 0;

    // DEBUG: Write to stderr to see if messages are in the queue
    const stderr_file = std.fs.File.stderr();
    var debug_buf: [256]u8 = undefined;
    const debug_msg = std.fmt.bufPrint(&debug_buf, "[dispatchWorkerMessages] worker={*} outside_port={*} queue len={d}, has_messages={}\n", .{ dedicated_worker, dedicated_worker.port_pair.outside_port, outside_queue_len, has_messages }) catch "[dispatchWorkerMessages] check\n";
    stderr_file.writeAll(debug_msg) catch {};

    // Dispatch worker→main messages
    if (has_messages) {
        stderr_file.writeAll("[dispatchWorkerMessages] Calling processQueuedMessages\n") catch {};
        dedicated_worker.processQueuedMessages();
        processAllPendingMessages(internal);
    }
}

/// Process all pending messages across all worker ports.
/// This handles the case where message handlers post to different workers.
fn processAllPendingMessages(initial_internal: *InternalState) void {
    // Keep processing until no more messages are pending
    var iterations: usize = 0;
    const max_iterations: usize = 100; // Prevent infinite loops

    while (iterations < max_iterations) {
        iterations += 1;

        // Flush pending messages and get the ports that received them
        var affected_ports = DedicatedWorker.flushPendingMessagesAndGetPorts(initial_internal.allocator) catch return;
        defer affected_ports.deinit(initial_internal.allocator);

        if (affected_ports.items.len == 0) {
            break; // No more pending messages
        }

        // Process messages on each affected port
        for (affected_ports.items) |port| {
            while (port.message_queue.items.len > 0) {
                const queued_msg = port.message_queue.orderedRemove(0);
                if (port.on_message) |handler| {
                    handler(port, queued_msg, port.on_message_context);
                }
                queued_msg.deinit();
            }
        }
    }

    if (iterations >= max_iterations) {
        std.log.warn("processAllPendingMessages: hit max iterations", .{});
    }
}

/// Callback to dispatch worker messages in a clean V8 state.
///
/// This runs in a separate timer callback (not immediately after worker script
/// execution) to ensure V8's HandleScope state is properly restored.
///
/// The event loop's timer handling runs after V8 microtask checkpoints,
/// so we're guaranteed to have a valid HandleScope context here.
fn dispatchWorkerMessagesCallback(user_data: ?*anyopaque) void {
    const instance: *runtime.Instance = @ptrCast(@alignCast(user_data orelse return));
    const internal = getInternal(instance) orelse return;
    const dedicated_worker = internal.dedicated_worker orelse return;

    // Now dispatch messages - we're in a clean V8 state with proper HandleScope
    dedicated_worker.processQueuedMessages();
}

/// Execute worker script synchronously (internal helper)
/// Called from either executeWorkerScriptCallback or synchronous fallback
///
/// CRITICAL DESIGN NOTE:
/// V8's HandleScope state is per-isolate and becomes corrupted when we switch
/// between isolates on the same thread. The worker's executeScript() enters the
/// worker isolate, which invalidates any HandleScope state in the main isolate.
///
/// Therefore, we MUST NOT do any V8 operations (like message dispatch) immediately
/// after worker script execution. Instead, we queue a task to dispatch messages
/// in the next event loop iteration, where the HandleScope state is clean.
///
/// Returns: true if messages were queued for dispatch, false otherwise
fn executeWorkerScriptSync(internal: *InternalState) bool {
    std.log.debug("[executeWorkerScriptSync] ENTRY", .{});
    const dedicated_worker = internal.dedicated_worker orelse {
        std.log.debug("[executeWorkerScriptSync] No dedicated_worker, returning", .{});
        return false;
    };
    const script = internal.pending_script orelse {
        std.log.debug("[executeWorkerScriptSync] No pending_script, returning", .{});
        return false;
    };
    std.log.debug("[executeWorkerScriptSync] Script len={d}, preview: {s}", .{ script.len, script[0..@min(script.len, 80)] });

    // Execute the script in WorkerV8Context - this is the SAME context used for message dispatch.
    // CRITICAL: We must use internal.v8_context, not dedicated_worker.executeScript(), because:
    // - internal.v8_context is WorkerV8Context (has onmessage dispatch)
    // - dedicated_worker.executeScript() uses WorkerContext (different V8 context!)
    // - If we execute in the wrong context, onmessage won't be set where we dispatch.
    if (internal.v8_context) |v8_ctx| {
        std.log.err("[executeWorkerScriptSync] Have v8_context, calling executeScript on ptr {*}", .{v8_ctx});
        _ = v8_ctx.executeScript(script) catch |err| {
            std.log.err("[executeWorkerScriptSync] Failed to execute: {}", .{err});
        };
        std.log.err("[executeWorkerScriptSync] executeScript returned", .{});
    } else {
        std.log.err("[executeWorkerScriptSync] No WorkerV8Context!", .{});
    }

    // Flush pending messages to port queues
    // This is a pure Zig operation - NO V8 operations!
    DedicatedWorker.flushPendingMessages();

    // Free the script source
    internal.allocator.free(script);
    internal.pending_script = null;

    // Check if there are messages to dispatch
    const queue_len = dedicated_worker.port_pair.outside_port.message_queue.items.len;

    // DO NOT dispatch messages here!
    // The V8 HandleScope state is corrupted after worker isolate enter/exit.
    // Messages will be dispatched by the event loop in the next iteration,
    // where the HandleScope is properly managed.
    //
    // The event loop will call processQueuedMessages() in its runOnce() or via
    // a queued task, both of which have clean HandleScope state.

    return queue_len > 0;
}

/// Callback for messages received from the worker via the outside port
///
/// Spec: HTML Standard § 10.2.3
/// "When a message is received on the outside port..."
/// 1. Deserialize the message data
/// 2. Create a MessageEvent with the data
/// 3. Dispatch the event (invoke onmessage handler)
///
/// This is called by DedicatedWorker when a message arrives from the worker
/// on the outside_port (worker → main thread direction).
fn handleMessageFromWorkerCallback(dedicated_worker: *DedicatedWorker, msg: *QueuedMessage) void {
    // Get the Worker instance from user_data stored in DedicatedWorker
    const user_data = dedicated_worker.getUserData() orelse return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(user_data));

    // Dispatch the message event to onmessage handler
    dispatchMessageEvent(instance, msg);
}

/// Callback to handle errors from the worker
///
/// This is called by DedicatedWorker when an uncaught error occurs in the worker
/// and self.onerror didn't handle it. We create an ErrorEvent and dispatch it
/// to the Worker object's onerror handler.
///
/// Spec: HTML Standard § 10.2.5 step 11
/// "Queue a task to fire an event named error at worker."
fn handleErrorFromWorkerCallback(dedicated_worker: *DedicatedWorker, error_event: *WorkerErrorEvent) void {
    // Get the Worker instance from user_data stored in DedicatedWorker
    const user_data = dedicated_worker.getUserData() orelse {
        error_event.deinit();
        return;
    };
    const instance: *runtime.Instance = @ptrCast(@alignCast(user_data));

    // Dispatch the error event to onerror handler
    dispatchWorkerErrorEvent(instance, error_event);
}

/// Dispatch an ErrorEvent to the Worker's error handlers
///
/// This creates an ErrorEvent with the error details and invokes:
/// 1. All registered "error" event listeners (via addEventListener)
/// 2. The onerror EventHandler if set
///
/// Per HTML Standard, if the error is not cancelled (preventDefault not called),
/// the error should propagate to the global error handler.
fn dispatchWorkerErrorEvent(instance: *runtime.Instance, error_event: *WorkerErrorEvent) void {
    defer error_event.deinit();

    // Get internal state with GlobalHandle and isolate
    const internal = getInternal(instance) orelse return;

    // Get isolate and V8 context
    const isolate = internal.isolate orelse return;
    const ctx = internal.ctx orelse return;
    const v8_context: *v8_engine.ffi.Context = ctx.getEngineContextAs(v8_engine.ffi.Context) orelse return;

    // Check current isolate state and enter if needed
    const current_isolate = v8_engine.ffi.v8_Isolate_GetCurrent();
    const need_enter_isolate = (current_isolate == null) or (current_isolate != isolate);
    if (need_enter_isolate) {
        v8_engine.ffi.v8_Isolate_Enter(isolate);
    }
    defer if (need_enter_isolate) {
        v8_engine.ffi.v8_Isolate_Exit(isolate);
    };

    // Verify we have a valid context, enter if needed
    const current_context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate);
    const need_enter_context = (current_context == null) or (current_context != v8_context);
    if (need_enter_context) {
        v8_engine.ffi.v8_Context_Enter(v8_context);
    }
    defer if (need_enter_context) {
        v8_engine.ffi.v8_Context_Exit(v8_context);
    };

    // Create a HandleScope for V8 operations
    // V8 requires a HandleScope when creating Local handles (from v8_Global_Get, etc.)
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(isolate);
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Create V8 ErrorEvent object
    // Per HTML Standard § 7.2.2 The ErrorEvent interface
    const error_event_js = createV8ErrorEvent(isolate, v8_context, error_event) orelse return;

    // Get onerror handler from internal state
    if (internal.onerror_handle) |handler_global| {
        // handler_global.ptr is already a Global<Value>* - pass it directly to v8_Value_IsFunction
        // which expects Global<Value>* (the FFI type is *Value but maps to Global<Value>* in C++)
        const handler: *v8_engine.ffi.Value = @ptrCast(handler_global.ptr);

        // Check if it's a function
        if (v8_engine.ffi.v8_Value_IsFunction(handler)) {
            const handler_fn: *v8_engine.ffi.Function = @ptrCast(handler_global.ptr);
            const global_obj = v8_engine.ffi.v8_Context_Global(v8_context) orelse return;

            // Call onerror handler with the ErrorEvent as argument
            // error_event_js is already a Global<Object>* from v8_Function_NewInstance
            // No need to convert - just cast to *Value for v8_Function_Call
            var args = [1]*v8_engine.ffi.Value{error_event_js};
            _ = v8_engine.ffi.v8_Function_Call(
                handler_fn,
                v8_context,
                @ptrCast(global_obj),
                1,
                &args,
            );
        }
    }

    // TODO: Also dispatch to event listeners via EventTarget.dispatchEvent
    // This would handle addEventListener('error', ...) but requires creating a proper
    // ErrorEvent instance. For now, the onerror property handler is handled above.
}

/// Create a V8 ErrorEvent object from WorkerErrorEvent data
/// Creates a proper ErrorEvent instance by calling the ErrorEvent constructor
fn createV8ErrorEvent(isolate: *v8_engine.ffi.Isolate, context: *v8_engine.ffi.Context, error_event: *WorkerErrorEvent) ?*v8_engine.ffi.Value {
    // Get the global object to access ErrorEvent constructor
    const global_obj = v8_engine.ffi.v8_Context_Global(context) orelse return null;

    // Get ErrorEvent constructor from global
    const error_event_name = v8_engine.ffi.v8_String_NewFromUtf8(isolate, "ErrorEvent", 10) orelse return null;
    const error_event_ctor_value = v8_engine.ffi.v8_Object_Get(global_obj, context, @ptrCast(error_event_name)) orelse return null;

    // Check if it's a function (constructor) - use Global version since v8_Object_Get returns Global*
    if (!v8_engine.ffi.v8_Value_IsFunction(@ptrCast(error_event_ctor_value))) {
        return null;
    }
    const error_event_ctor: *v8_engine.ffi.Function = @ptrCast(@alignCast(error_event_ctor_value));

    // Create the ErrorEventInit dictionary
    const init_dict = v8_engine.ffi.v8_Object_New(isolate) orelse return null;

    // Set message
    const message_key = v8_engine.ffi.v8_String_NewFromUtf8(isolate, "message", 7) orelse return null;
    const message_val = v8_engine.ffi.v8_String_NewFromUtf8(isolate, error_event.message.ptr, @intCast(error_event.message.len)) orelse return null;
    _ = v8_engine.ffi.v8_Object_Set(init_dict, context, @ptrCast(message_key), @ptrCast(message_val));

    // Set filename
    const filename_key = v8_engine.ffi.v8_String_NewFromUtf8(isolate, "filename", 8) orelse return null;
    const filename_val = v8_engine.ffi.v8_String_NewFromUtf8(isolate, error_event.filename.ptr, @intCast(error_event.filename.len)) orelse return null;
    _ = v8_engine.ffi.v8_Object_Set(init_dict, context, @ptrCast(filename_key), @ptrCast(filename_val));

    // Set lineno
    const lineno_key = v8_engine.ffi.v8_String_NewFromUtf8(isolate, "lineno", 6) orelse return null;
    const lineno_val = v8_engine.ffi.v8_Integer_New(isolate, @intCast(error_event.lineno));
    _ = v8_engine.ffi.v8_Object_Set(init_dict, context, @ptrCast(lineno_key), @ptrCast(lineno_val));

    // Set colno
    const colno_key = v8_engine.ffi.v8_String_NewFromUtf8(isolate, "colno", 5) orelse return null;
    const colno_val = v8_engine.ffi.v8_Integer_New(isolate, @intCast(error_event.colno));
    _ = v8_engine.ffi.v8_Object_Set(init_dict, context, @ptrCast(colno_key), @ptrCast(colno_val));

    // Set error to an Error object
    const error_key = v8_engine.ffi.v8_String_NewFromUtf8(isolate, "error", 5) orelse return null;
    const error_obj = v8_engine.ffi.v8_Exception_ErrorInContext(context, message_val) orelse return null;
    _ = v8_engine.ffi.v8_Object_Set(init_dict, context, @ptrCast(error_key), error_obj);

    // Set cancelable = true (error events can be cancelled with preventDefault)
    const cancelable_key = v8_engine.ffi.v8_String_NewFromUtf8(isolate, "cancelable", 10) orelse return null;
    const cancelable_val = v8_engine.ffi.v8_Boolean_New(isolate, true) orelse return null;
    _ = v8_engine.ffi.v8_Object_Set(init_dict, context, @ptrCast(cancelable_key), cancelable_val);

    // Create event type string "error"
    const type_str = v8_engine.ffi.v8_String_NewFromUtf8(isolate, "error", 5) orelse return null;

    // Call ErrorEvent constructor: new ErrorEvent("error", initDict)
    var args = [2]*v8_engine.ffi.Value{ @ptrCast(type_str), @ptrCast(init_dict) };
    const event_obj = v8_engine.ffi.v8_Function_NewInstance(error_event_ctor, context, 2, &args) orelse {
        std.log.warn("[createV8ErrorEvent] Failed to create ErrorEvent instance", .{});
        return null;
    };

    return @ptrCast(event_obj);
}

/// Dispatch a MessageEvent to the Worker's message handlers
///
/// This creates a MessageEvent with the deserialized data and invokes:
/// 1. All registered "message" event listeners (via addEventListener)
/// 2. The onmessage EventHandler if set
///
/// ## V8 Callback Invocation
///
/// Event listeners are stored as CallbackWrapper instances that hold Global handles
/// to JavaScript functions. We invoke them via CallbackWrapper.call1().
///
/// The EventHandler (onmessage) is a tagged pointer to a V8 GlobalHandle that we
/// invoke directly via v8_Function_Call.
///
/// ## JSON Message Handling
///
/// Worker messages are now serialized as JSON strings for cross-isolate safety.
/// This function:
/// 1. Extracts the JSON string from the SerializedValue
/// 2. Parses it using V8's JSON.parse in the main context
/// 3. Creates MessageEvent with the parsed value as data
fn dispatchMessageEvent(instance: *runtime.Instance, msg: *QueuedMessage) void {
    // Get internal state with GlobalHandle and isolate
    const internal = getInternal(instance) orelse return;

    // DEBUG: Log the instance we're dispatching to
    const stderr_file = std.fs.File.stderr();
    var debug_buf: [256]u8 = undefined;
    const debug_msg = std.fmt.bufPrint(&debug_buf, "[dispatchMessageEvent] ENTRY instance={*}, dedicated_worker={?*}\n", .{ instance, internal.dedicated_worker }) catch "[dispatchMessageEvent] ENTRY\n";
    stderr_file.writeAll(debug_msg) catch {};

    // Get isolate and V8 context
    const isolate = internal.isolate orelse return;
    const ctx = internal.ctx orelse return;
    const v8_context: *v8_engine.ffi.Context = ctx.getEngineContextAs(v8_engine.ffi.Context) orelse return;

    // Check current isolate state
    const current_isolate = v8_engine.ffi.v8_Isolate_GetCurrent();

    // We need to be in the main isolate to dispatch events.
    // After worker script execution, we may be in a different isolate
    // (e.g., a previous test's isolate). We must enter the correct isolate.
    const need_enter_isolate = (current_isolate == null) or (current_isolate != isolate);
    if (need_enter_isolate) {
        v8_engine.ffi.v8_Isolate_Enter(isolate);
    }
    defer if (need_enter_isolate) {
        v8_engine.ffi.v8_Isolate_Exit(isolate);
    };

    // Verify we have a valid context, enter if needed
    const current_context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate);
    const need_enter_context = (current_context == null) or (current_context != v8_context);
    if (need_enter_context) {
        v8_engine.ffi.v8_Context_Enter(v8_context);
    }
    defer if (need_enter_context) {
        v8_engine.ffi.v8_Context_Exit(v8_context);
    };

    // CRITICAL: Create HandleScope for V8 operations.
    // We need our own HandleScope because:
    // 1. Timer callbacks may enter/exit different isolates (worker isolates)
    // 2. The outer HandleScope from runOnce was removed to avoid HandleScope
    //    corruption during cross-isolate transitions
    // 3. Each V8 operation needs a valid HandleScope for the current isolate
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(isolate);
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Get the message data - check the serialization type
    var v8_data: ?*v8_engine.ffi.Value = null;

    // Check if this is V8-serialized data (from cross-isolate transfer with ArrayBuffers)
    if (msg.data.type == .v8_serialized) {
        const v8_serialized = msg.data.data.v8_serialized;

        // Build ArrayBufferTransferData array from the transferred data
        var arraybuffer_data: [64]v8_engine.ffi.ArrayBufferTransferData = undefined;
        const ab_count = @min(v8_serialized.transferred_arraybuffers.len, 64);

        for (0..ab_count) |i| {
            const transferred = v8_serialized.transferred_arraybuffers[i];
            arraybuffer_data[i] = .{
                .data = if (transferred.data.len > 0) transferred.data.ptr else null,
                .size = transferred.byte_length,
            };
        }

        // Deserialize using cross-isolate API
        var error_code: i32 = 0;
        v8_data = v8_engine.ffi.v8_Value_DeserializeWithTransfer_CrossIsolate(
            v8_serialized.serialized_bytes.ptr,
            v8_serialized.serialized_bytes.len,
            &arraybuffer_data,
            ab_count,
            &error_code,
        );

        if (v8_data == null or error_code != 0) {
            std.log.warn("Worker.dispatchMessageEvent: V8 deserialization failed with error code {}", .{error_code});
        }
    }

    // Check for JSON-serialized primitives (from postMessage without transfer)
    if (v8_data == null and msg.data.type == .primitive) {
        switch (msg.data.data.primitive) {
            .string => |json_str| {
                // DEBUG
                var json_debug_buf: [256]u8 = undefined;
                const preview_len = @min(json_str.len, 50);
                const json_debug_msg = std.fmt.bufPrint(&json_debug_buf, "[dispatchMessageEvent] Parsing JSON: len={d}, content={s}\n", .{ json_str.len, json_str[0..preview_len] }) catch "[dispatchMessageEvent]\n";
                stderr_file.writeAll(json_debug_msg) catch {};

                // JSON string from worker - parse it in main context
                v8_data = v8_engine.ffi.v8_JSON_Parse_FromBuffer(
                    v8_context,
                    json_str.ptr,
                    @intCast(json_str.len),
                );
                if (v8_data == null) {
                    std.log.warn("Worker.dispatchMessageEvent: JSON.parse failed for: {s}", .{json_str});
                } else {
                    stderr_file.writeAll("[dispatchMessageEvent] JSON parse SUCCEEDED\n") catch {};
                }
            },
            else => {},
        }
    }

    // If we couldn't get V8 data, try the old deserialization path
    if (v8_data == null) {
        // Fall back to structured clone deserialization
        const deserialized = workers.message_channel.deserializeFromPostMessage(
            ctx.allocator,
            msg.data,
        ) catch |err| {
            std.log.warn("Failed to deserialize worker message: {}", .{err});
            return;
        };

        // Create a MessageEvent with the deserialized data
        const message_event = MessageEvent.call_constructor(
            ctx,
            runtime.DOMString.initInterned("message"),
            webidl.Opt(dictionaries.MessageEventInit).notPassed(),
        ) catch |err| {
            std.log.warn("Failed to create MessageEvent: {}", .{err});
            workers.message_channel.freeJSValue(ctx.allocator, @constCast(deserialized));
            return;
        };

        var event_state = message_event.getState(MessageEvent.State);
        // deserialized is a V8 handle from message channel deserialization
        event_state.own.data = runtime.JSValue.fromHandleNonOwning(@ptrCast(@constCast(deserialized)));

        // Wrap and dispatch
        const v8_event = template_registry.wrapInstanceAsV8Object(
            message_event,
            "MessageEvent",
            isolate,
            v8_context,
        ) catch |err| {
            std.log.warn("Failed to wrap MessageEvent as V8 object: {s}", .{@errorName(err)});
            return;
        };

        // Dispatch to all listeners and onmessage handler
        invokeMessageListeners(instance, isolate, v8_context, v8_event, internal);
        return;
    }

    // We have V8 data from JSON.parse - create MessageEvent with it
    const message_event = MessageEvent.call_constructor(
        ctx,
        runtime.DOMString.initInterned("message"),
        webidl.Opt(dictionaries.MessageEventInit).notPassed(),
    ) catch |err| {
        std.log.warn("Failed to create MessageEvent: {}", .{err});
        if (v8_data) |data| {
            v8_engine.ffi.v8_Value_Dispose(data);
        }
        return;
    };

    // Set the data property on the MessageEvent
    // v8_JSON_Parse_FromBuffer returns a Local handle that's only valid in the current HandleScope.
    // When the callback executes (via v8_Function_Call), it may create its own HandleScope.
    // The callback then accesses message.data, which triggers our getter.
    // At that point, the original Local handle might not be valid.
    //
    // Solution: Convert the Local to a Global handle for safe storage.
    // The Global handle persists across HandleScope boundaries.
    const global_data = v8_engine.ffi.v8_Value_ToGlobal(isolate, @ptrCast(v8_data)) orelse {
        std.log.warn("Failed to convert JSON data to Global handle", .{});
        return;
    };
    // Note: This Global handle will NOT be automatically disposed.
    // Since MessageEvent is short-lived (only used for this dispatch), this is acceptable.
    // The Global handle will be collected when the isolate is disposed.
    // TODO: Properly track and dispose this Global handle when MessageEvent is destroyed.

    var event_state = message_event.getState(MessageEvent.State);
    event_state.own.data = runtime.JSValue.fromHandle(@ptrCast(global_data));

    // Wrap the MessageEvent instance as a V8 Object
    const v8_event = template_registry.wrapInstanceAsV8Object(
        message_event,
        "MessageEvent",
        isolate,
        v8_context,
    ) catch |err| {
        std.log.warn("Failed to wrap MessageEvent as V8 object: {s}", .{@errorName(err)});
        return;
    };

    // Dispatch to all listeners and onmessage handler
    invokeMessageListeners(instance, isolate, v8_context, v8_event, internal);
}

/// Invoke all registered "message" event listeners and the onmessage handler
///
/// Per DOM spec, event listeners registered via addEventListener are invoked first,
/// then the legacy event handler (onmessage) is invoked.
fn invokeMessageListeners(
    instance: *runtime.Instance,
    isolate: *v8_engine.ffi.Isolate,
    v8_context: *v8_engine.ffi.Context,
    v8_event: *v8_engine.ffi.Object,
    internal: *InternalState,
) void {
    // DEBUG
    const stderr_file = std.fs.File.stderr();
    var debug_buf: [128]u8 = undefined;
    const has_handler = internal.onmessage_handle != null;
    const debug_msg = std.fmt.bufPrint(&debug_buf, "[invokeMessageListeners] ENTRY, has_onmessage_handler={}\n", .{has_handler}) catch "[invokeMessageListeners]\n";
    stderr_file.writeAll(debug_msg) catch {};

    // EventTargetImpl is imported at module level
    const CallbackWrapper = v8_engine.CallbackWrapper;

    // Step 1: Invoke registered "message" event listeners (from addEventListener)
    if (EventTargetImpl.getInternalState(instance)) |et_internal| {
        const listeners = et_internal.getEventListenerList();
        for (listeners) |listener| {
            // Check if listener is for "message" events and not removed
            if (std.mem.eql(u8, listener.type.asSlice(), "message") and !listener.removed) {
                // listener.callback is actually a *CallbackWrapper
                if (listener.callback) |callback_instance| {
                    const callback_wrapper: *CallbackWrapper = @ptrCast(@alignCast(callback_instance));

                    // NOTE: We can't use callback_wrapper.call1() here because v8_event is
                    // already a Global<Object>*, and call1's v8_Value_ToGlobal() assumes
                    // the argument is a Local handle. Instead, we directly invoke the V8
                    // function using v8_Function_Call which expects Global handles.
                    //
                    // callback_function_global.ptr is already a Global<Function>*
                    if (callback_wrapper.callback_function_global) |func_global| {
                        const undefined_recv = v8_engine.ffi.v8_Undefined(isolate);

                        // Both func_global.ptr and v8_event are Global handles,
                        // which is exactly what v8_Function_Call expects
                        var args = [_]*v8_engine.ffi.Value{@ptrCast(v8_event)};
                        _ = v8_engine.ffi.v8_Function_Call(
                            @ptrCast(func_global.ptr),
                            v8_context,
                            @ptrCast(undefined_recv),
                            1,
                            &args,
                        );
                    }
                }
            }
        }
    }

    // Step 2: Invoke the onmessage handler if set
    if (internal.onmessage_handle) |onmessage_global| {
        stderr_file.writeAll("[invokeMessageListeners] Step 2: has onmessage_handle\n") catch {};

        // Verify it's a function using the Global handle directly
        // v8_Value_IsFunction expects a Global<Value>* which is what rawPtr() returns
        if (!v8_engine.ffi.v8_Value_IsFunction(onmessage_global.rawPtr())) {
            stderr_file.writeAll("[invokeMessageListeners] WARN: onmessage_handle is not a function!\n") catch {};
            return;
        }

        stderr_file.writeAll("[invokeMessageListeners] onmessage_handle is a function, calling...\n") catch {};

        // Get the function as a Global<Function>* for the call
        // We can safely cast since we verified it's a function above
        const global_func = v8_engine.ffi.v8_Global_ToFunction(onmessage_global.rawPtr()) orelse {
            stderr_file.writeAll("[invokeMessageListeners] WARN: Global_ToFunction returned null!\n") catch {};
            return;
        };

        // Call the V8 function with the MessageEvent as argument
        const undefined_recv = v8_engine.ffi.v8_Undefined(isolate);
        var args = [_]*v8_engine.ffi.Value{@ptrCast(v8_event)};

        // DEBUG: Check v8_event is valid before call
        {
            var event_buf: [128]u8 = undefined;
            const event_is_obj = v8_engine.ffi.v8_Value_IsObject(@ptrCast(v8_event));
            const event_msg = std.fmt.bufPrint(&event_buf, "[invokeMessageListeners] v8_event is_object={}\n", .{event_is_obj}) catch "[invokeMessageListeners] v8_event check\n";
            stderr_file.writeAll(event_msg) catch {};
        }

        const result = v8_engine.ffi.v8_Function_Call(global_func, v8_context, @ptrCast(undefined_recv), 1, &args);
        if (result != null) {
            stderr_file.writeAll("[invokeMessageListeners] V8 function call SUCCEEDED\n") catch {};
        } else {
            stderr_file.writeAll("[invokeMessageListeners] WARN: V8 function call returned null\n") catch {};
            // Check for exception
            const exception = v8_engine.ffi.v8_TryCatch_Exception(v8_context);
            if (exception != null) {
                stderr_file.writeAll("[invokeMessageListeners] V8 has exception!\n") catch {};
            }
        }
    } else {
        stderr_file.writeAll("[invokeMessageListeners] Step 2: NO onmessage_handle\n") catch {};
    }
}

/// Operation: terminate
///
/// Spec: HTML Standard § 10.2.3.1 terminate()
/// "The terminate() method, when invoked, must cause the terminate a worker
/// algorithm to be run on the worker with which the object is associated."
pub fn call_terminate(instance: *runtime.Instance) anyerror!void {
    // DEBUG: Log the terminate call
    const stderr_file = std.fs.File.stderr();
    stderr_file.writeAll("[Worker.call_terminate] ENTRY\n") catch {};

    const state = instance.getState(State);
    if (state.own._internal) |internal_ptr| {
        // Mark as terminated
        const internal = @constCast(internal_ptr);
        internal.terminated = true;
        if (internal.dedicated_worker) |worker| {
            var buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "[Worker.call_terminate] worker={*}, agent={*}\n", .{ worker, worker.agent }) catch "[Worker.call_terminate] worker\n";
            stderr_file.writeAll(msg) catch {};
            worker.terminate();
        }
    }
}

/// Operation: postMessage
///
/// Spec: HTML Standard § 10.2.3.1 postMessage(message, transfer)
/// Posts a message to the worker. Uses structured clone algorithm.
///
/// The message is serialized using the structured clone algorithm and
/// sent to the worker's message queue.
///
/// For cross-isolate transfer (Worker runs in separate V8 isolate):
/// 1. Extract ArrayBuffers from transfer list
/// 2. Serialize message to bytes (V8 ValueSerializer)
/// 3. Copy ArrayBuffer data before detaching
/// 4. Detach original ArrayBuffers
/// 5. Pass serialized bytes + ArrayBuffer data to worker
/// 6. Worker deserializes in its own isolate
pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    if (internal.terminated) return; // Worker is terminated, ignore message

    const allocator = internal.allocator;

    // Get V8 context and isolate for serialization
    const ctx = instance.ctx;
    const engine_ctx = ctx.getEngineContext() orelse return error.NoEngine;
    const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoEngine;

    // Convert JSValue to V8 Value* for serialization
    const v8_value: *v8_engine.ffi.Value = switch (message) {
        .handle => |h| blk: {
            if (h.handle_scope == .global) {
                const global_ptr: *v8_engine.ffi.Value = @ptrCast(@alignCast(h.ptr));
                const local_result = v8_engine.ffi.v8_Global_Get(isolate, global_ptr) orelse return error.NoValue;
                break :blk @ptrCast(@alignCast(local_result));
            } else {
                break :blk @ptrCast(@alignCast(h.ptr));
            }
        },
        .undefined => v8_engine.ffi.v8_Undefined(isolate) orelse return error.NoValue,
        .null => v8_engine.ffi.v8_Null(isolate) orelse return error.NoValue,
        .boolean => |b| v8_engine.ffi.v8_Boolean_New(isolate, b) orelse return error.NoValue,
        .number => |n| @ptrCast(v8_engine.ffi.v8_Number_New(isolate, n)),
        .string => |s| @ptrCast(v8_engine.ffi.v8_String_NewFromUtf8(isolate, s.data.ptr, @intCast(s.data.len)) orelse return error.NoValue),
        .instance => return error.UnsupportedValueType,
    };

    // Step 1: Extract ArrayBuffers and MessagePorts from transfer list
    var array_buffer_transfers: [64]*v8_engine.ffi.Value = undefined;
    var array_buffer_count: usize = 0;

    // MessagePort transfers - store the internal port pointers
    var port_transfers: [16]*MessagePortImpl.InternalState = undefined;
    var port_count: usize = 0;

    if (transfer == .handle) {
        const transfer_handle = transfer.handle;
        const transfer_value: *v8_engine.ffi.Value = @ptrCast(@alignCast(transfer_handle.ptr));

        if (v8_engine.ffi.v8_Value_IsArray(transfer_value)) {
            const transfer_array: *v8_engine.ffi.Array = @ptrCast(transfer_value);
            const length = v8_engine.ffi.v8_Array_Length(transfer_array);

            for (0..length) |i| {
                if (v8_engine.ffi.v8_Array_Get(v8_context, transfer_array, @intCast(i))) |item| {
                    // Check for ArrayBuffer
                    if (v8_engine.ffi.v8_Value_IsArrayBuffer(item)) {
                        if (array_buffer_count < 64) {
                            array_buffer_transfers[array_buffer_count] = item;
                            array_buffer_count += 1;
                        }
                    }
                    // Check for MessagePort - must be a WebIDL object with MessagePort vtable
                    else if (v8_engine.ffi.v8_Value_IsObject(item)) {
                        const obj: *v8_engine.ffi.Object = @ptrCast(item);
                        // Get internal field 0 (runtime.Instance pointer)
                        if (v8_engine.ffi.v8_Object_GetAlignedPointerFromInternalField(obj, 0)) |ptr| {
                            const port_instance: *runtime.Instance = @ptrCast(@alignCast(ptr));
                            // Check if vtable matches MessagePort
                            if (port_instance.vtable == &interfaces.MessagePort.vtable) {
                                if (port_count < 16) {
                                    // Get the MessagePort state and internal port
                                    const port_state = port_instance.getState(interfaces.MessagePort.State);
                                    if (port_state.own._internal) |port_internal| {
                                        // Store the internal state for transfer
                                        port_transfers[port_count] = port_internal;
                                        port_count += 1;

                                        // Per HTML Standard § 9.4.4: transferred ports are disentangled
                                        // from their WebIDL layer but KEEP internal entanglement for
                                        // message routing. The internal entangled_port must remain
                                        // intact so messages can flow between the ports.
                                        //
                                        // Clear WebIDL entanglement (source wrapper becomes neutered)
                                        // but don't call internal_port.disentangle()
                                        port_internal.entangled_webidl_port = null;

                                        // Mark the internal port as transferred for cross-isolate messaging
                                        port_internal.internal_port.transferred = true;

                                        // Mark source as no longer owning the port
                                        // Ownership transfers to the destination
                                        port_internal.owns_port = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Step 2: Serialize with transfer using cross-isolate API
    // Use V8 serialization if we have ArrayBuffers or MessagePorts to transfer
    if (array_buffer_count > 0 or port_count > 0) {
        // Use V8 cross-isolate serialization with ArrayBuffer transfer
        var arraybuffer_data: [64]v8_engine.ffi.ArrayBufferTransferData = undefined;
        var serialized_size: usize = 0;
        var error_code: i32 = 0;

        const serialized_bytes = v8_engine.ffi.v8_Value_SerializeWithTransfer_CrossIsolate(
            v8_value,
            &array_buffer_transfers,
            array_buffer_count,
            &serialized_size,
            &arraybuffer_data,
            &error_code,
        );

        if (serialized_bytes == null or error_code != 0) {
            return error.SerializationFailed;
        }

        // Copy the serialized bytes to Zig-managed memory
        const bytes_copy = try allocator.alloc(u8, serialized_size);
        errdefer allocator.free(bytes_copy);
        @memcpy(bytes_copy, serialized_bytes.?[0..serialized_size]);

        // Free the V8-allocated serialized buffer
        v8_engine.ffi.v8_Free_SerializedBuffer(serialized_bytes.?);

        // Copy the ArrayBuffer data to Zig-managed memory
        const transferred_abs = try allocator.alloc(TransferredArrayBufferData, array_buffer_count);
        errdefer {
            for (transferred_abs) |ab| {
                allocator.free(ab.data);
            }
            allocator.free(transferred_abs);
        }

        for (0..array_buffer_count) |i| {
            const ab_data = arraybuffer_data[i];
            if (ab_data.size > 0 and ab_data.data != null) {
                const data_slice: [*]u8 = @ptrCast(ab_data.data.?);
                transferred_abs[i] = .{
                    .data = try allocator.dupe(u8, data_slice[0..ab_data.size]),
                    .byte_length = ab_data.size,
                };
            } else {
                transferred_abs[i] = .{
                    .data = &[_]u8{},
                    .byte_length = 0,
                };
            }
        }

        // Free the C-allocated ArrayBuffer data (we've copied it)
        v8_engine.ffi.v8_Free_ArrayBufferTransferData(&arraybuffer_data, array_buffer_count);

        // Step 3: Copy transferred MessagePort data
        const transferred_ports: []TransferredPortData = if (port_count > 0) blk: {
            const ports = try allocator.alloc(TransferredPortData, port_count);
            errdefer allocator.free(ports);
            for (0..port_count) |i| {
                ports[i] = .{
                    .internal_port = port_transfers[i].internal_port,
                };
            }
            break :blk ports;
        } else &[_]TransferredPortData{};

        // Create SerializedValue with V8 serialized data
        const serialized = try allocator.create(SerializedValue);
        errdefer allocator.destroy(serialized);

        serialized.* = .{
            .type = .v8_serialized,
            .allocator = allocator,
            .data = .{
                .v8_serialized = .{
                    .serialized_bytes = bytes_copy,
                    .transferred_arraybuffers = transferred_abs,
                    .transferred_ports = transferred_ports,
                },
            },
        };

        // Post to the worker's inside port (or queue if worker not ready)
        if (internal.dedicated_worker) |worker| {
            worker.port_pair.outside_port.postMessage(serialized, null) catch |err| {
                serialized.deinit();
                allocator.destroy(serialized);
                return switch (err) {
                    error.PortClosed => error.WorkerClosed,
                    error.NotEntangled => error.WorkerClosed,
                    else => error.PostMessageFailed,
                };
            };
        } else {
            // Queue for later - worker not ready yet
            try internal.pending_outgoing_messages.append(allocator, serialized);
        }
    } else {
        // No transfer list - use JSON serialization (simpler, works for primitives)
        var dummy_buf: [1]u8 = undefined;
        const required_size = v8_engine.ffi.v8_JSON_Stringify_ToBuffer(
            v8_context,
            v8_value,
            &dummy_buf,
            0,
        );
        if (required_size <= 0) return error.SerializationFailed;

        const json_buffer = try allocator.alloc(u8, @intCast(required_size + 1));
        defer allocator.free(json_buffer);

        const written = v8_engine.ffi.v8_JSON_Stringify_ToBuffer(
            v8_context,
            v8_value,
            json_buffer.ptr,
            @intCast(json_buffer.len),
        );
        if (written <= 0) return error.SerializationFailed;

        const json_str = json_buffer[0..@intCast(written)];

        const serialized = try allocator.create(SerializedValue);
        errdefer allocator.destroy(serialized);

        const json_copy = try allocator.dupe(u8, json_str);
        errdefer allocator.free(json_copy);

        serialized.* = .{
            .type = .primitive,
            .allocator = allocator,
            .data = .{ .primitive = .{ .string = json_copy } },
        };

        // Post to the worker's inside port (or queue if worker not ready)
        if (internal.dedicated_worker) |worker| {
            worker.port_pair.outside_port.postMessage(serialized, null) catch |err| {
                serialized.deinit();
                allocator.destroy(serialized);
                return switch (err) {
                    error.PortClosed => error.WorkerClosed,
                    error.NotEntangled => error.WorkerClosed,
                    else => error.PostMessageFailed,
                };
            };
        } else {
            // Queue for later - worker not ready yet
            try internal.pending_outgoing_messages.append(allocator, serialized);
        }
    }

    // CRITICAL: Only process messages if the worker script has been evaluated.
    // Per Chromium's DedicatedWorkerMessagingProxy::was_script_evaluated_ pattern:
    // - If script hasn't run yet, messages are queued and will be processed later
    //   in executeWorkerScriptCallback after the script finishes
    // - If script HAS run, we can immediately dispatch to self.onmessage
    //
    // Without this check, messages posted before the script runs would try to
    // dispatch to a non-existent onmessage handler.
    if (internal.script_evaluated) {
        if (internal.v8_context) |v8_ctx| {
            html_full.worker_v8_context.processIncomingMessages(v8_ctx);

            // After processing, check if worker sent back any messages and dispatch them
            // This handles the echo pattern: main → worker → main
            if (internal.dedicated_worker) |dw| {
                if (dw.port_pair.outside_port.message_queue.items.len > 0) {
                    dw.processQueuedMessages();
                }
            }
        }
    }
}
