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

// Import workers infrastructure
const html_core = @import("html_core");
const workers = html_core.workers;
const DedicatedWorker = workers.DedicatedWorker;
const WorkerOptions = workers.WorkerOptions;
const WorkerType = workers.WorkerType;
const RequestCredentials = workers.RequestCredentials;
const QueuedMessage = workers.message_channel.QueuedMessage;
const WorkerContext = workers.WorkerContext;

// Import html module for WorkerV8Context (has interface access, unlike html_core)
const html_full = @import("html");
const WorkerV8Context = html_full.WorkerV8Context;

// Import structured clone for message passing
const structured_clone = html_core.structured_clone;

// Import MessagePort for communication
const message_port_internal = @import("streams_internal");
const InternalMessagePort = message_port_internal.MessagePort;

// Import platform for TimerBackend (used to create DedicatedWorker)
const platform = @import("platform");

// Import V8 engine for callback invocation
const v8_engine = @import("v8");
const template_registry = v8_engine.template_registry;

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

    pub fn deinit(self: *InternalState) void {
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
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
///
/// Spec: HTML Standard § 10.2.3.1 The Worker() constructor
/// https://html.spec.whatwg.org/#dom-worker
///
/// This is called when the interface is constructed from JavaScript:
/// new Worker(scriptURL, options)
pub fn call_constructor(ctx: runtime.Context, scriptURL: runtime.DOMString, options: webidl.Opt(dictionaries.WorkerOptions)) !*runtime.Instance {
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
    };

    // Store internal state in instance
    var state = instance.getState(State);
    state.own._internal = internal_state;

    // Try to create the DedicatedWorker using the global timer backend
    // The timer backend is portable (uses std.time) and works on all platforms
    if (platform.getDefaultTimerBackend(ctx.allocator)) |timer_backend| {
        const dedicated_worker = DedicatedWorker.init(
            ctx.allocator,
            timer_backend,
            url_copy,
            .{
                .name = name_copy,
                .worker_type = worker_type,
                .credentials = credentials,
            },
        ) catch |err| {
            // Log error but don't fail - worker will be in "not started" state
            std.log.warn("Failed to create DedicatedWorker: {}", .{err});
            return instance;
        };
        internal_state.dedicated_worker = dedicated_worker;

        // Store reference to Worker instance for message callbacks
        // This allows handleMessageFromWorkerCallback to find the Worker
        dedicated_worker.setUserData(instance);

        // Set up message handler on outside port to receive messages from worker
        // When the worker calls postMessage(), the message arrives at outside_port
        // and we dispatch to the onmessage handler.
        dedicated_worker.setOnMessage(handleMessageFromWorkerCallback);

        // Enable message dispatch on outside port
        // Messages are queued until start() is called
        dedicated_worker.startMessageQueue();

        // Create V8 context for worker execution
        // This creates a separate V8 isolate for the worker with its own context
        const v8_context = WorkerV8Context.init(
            ctx.allocator,
            url_copy,
            worker_type,
        ) catch |err| {
            std.log.warn("Failed to create WorkerV8Context: {}", .{err});
            return instance;
        };
        internal_state.v8_context = v8_context;

        // IMPORTANT: Create the WorkerContext FIRST before wiring up engine context
        // This calls agent.startWithContext() which creates the worker_context
        dedicated_worker.startWithContext() catch |err| {
            std.log.warn("Failed to start worker context: {}", .{err});
            return instance;
        };

        // Now wire up the V8 context to the WorkerAgent's WorkerContext
        // This connects the engine callbacks (compileAndRunScript, etc.) to V8 FFI
        if (dedicated_worker.agent.worker_context) |worker_ctx| {
            worker_ctx.setEngineContext(v8_context.getEngineContext(), v8_context.getCallbacks());
        } else {
            std.log.warn("WorkerContext not created after startWithContext", .{});
            return instance;
        }

        // Set up DedicatedWorkerGlobalScope with proper globals
        // This adds self.GLOBAL, postMessage, close, importScripts, console, etc.
        v8_context.setupWorkerGlobalScope(dedicated_worker) catch |err| {
            std.log.warn("Failed to set up worker global scope: {}", .{err});
            return instance;
        };

        // Start the worker's message queue so messages can be dispatched
        dedicated_worker.startWorkerMessageQueue();

        // Fetch and execute the worker script
        // This is the "run a worker" algorithm per HTML Standard § 10.2.5
        // For WPT tests, scripts are fetched from the WPT server or resolved as data: URLs
        const fetched_script = workers.fetchWorkerScript(ctx.allocator, url_copy, .{
            .worker_type = worker_type,
            .origin = null,
        }) catch |err| {
            // Log error but don't fail construction - worker enters error state
            // Per spec, errors during script fetch should fire an error event
            std.log.warn("Failed to fetch worker script: {}", .{err});
            return instance;
        };
        defer @constCast(&fetched_script).deinit();

        // Execute the fetched script
        dedicated_worker.executeScript(fetched_script.source) catch |err| {
            std.log.warn("Failed to execute worker script: {}", .{err});
            // TODO: Fire error event on Worker object
        };
        // Note: executeScript now handles enter/exit of worker isolate internally

        // Schedule message processing via setTimeout(0)
        // Per HTML spec, messages should be delivered asynchronously via the event loop.
        // If we dispatch here synchronously, the onmessage handler won't be set yet
        // (the constructor hasn't returned and fetch_tests_from_worker hasn't run).
        //
        // Using setTimeout(0) schedules a macrotask that runs after:
        // 1. The constructor returns
        // 2. JavaScript continues (e.g., fetch_tests_from_worker sets up handlers)
        // 3. The current script finishes
        // 4. The event loop runs the scheduled task
        if (ctx.timer) |timer| {
            std.log.debug("Worker: scheduling message processing via setTimeout(0)", .{});
            _ = timer.setTimeout(0, processQueuedMessagesCallback, instance);
        } else {
            // No timer available - fall back to immediate processing
            // This won't work correctly for WPT tests but allows basic functionality
            std.log.warn("Worker: no timer available, processing messages immediately", .{});
            dedicated_worker.processQueuedMessages();
        }
    } else |_| {
        // Timer backend initialization failed - worker remains in "not started" state
        std.log.warn("TimerBackend not available, worker will not start", .{});
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
        internal.onerror_handle = extractEventHandler(@ptrCast(value));
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

    // Also store as GlobalHandle in internal state for proper V8 invocation
    if (getInternal(instance)) |internal| {
        v8_engine.disposeOptionalGlobalHandle(&internal.onmessage_handle);
        internal.onmessage_handle = extractEventHandler(@ptrCast(value));

        // Process any messages that were queued before the handler was set
        // This ensures messages posted by the worker during script execution
        // are delivered now that there's a handler to receive them.
        if (internal.dedicated_worker) |dedicated_worker| {
            std.log.debug("set_onmessage: processing queued messages", .{});
            dedicated_worker.processQueuedMessages();
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
        internal.onmessageerror_handle = extractEventHandler(@ptrCast(value));
    }
}

/// Timer callback for deferred message processing
///
/// This callback is scheduled via setTimeout(0) after the worker script executes.
/// It runs after the current JavaScript (constructor call) returns, giving
/// fetch_tests_from_worker() a chance to set up message handlers.
fn processQueuedMessagesCallback(user_data: ?*anyopaque) void {
    std.log.debug("processQueuedMessagesCallback: timer fired", .{});

    const instance: *runtime.Instance = @ptrCast(@alignCast(user_data orelse {
        std.log.warn("processQueuedMessagesCallback: no user_data", .{});
        return;
    }));

    const internal = getInternal(instance) orelse {
        std.log.warn("processQueuedMessagesCallback: no internal state", .{});
        return;
    };

    if (internal.dedicated_worker) |dedicated_worker| {
        std.log.debug("processQueuedMessagesCallback: processing queued messages", .{});
        dedicated_worker.processQueuedMessages();
    }
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
    std.log.debug("handleMessageFromWorkerCallback: received message from worker", .{});

    // Get the Worker instance from user_data stored in DedicatedWorker
    const user_data = dedicated_worker.getUserData() orelse {
        std.log.debug("handleMessageFromWorkerCallback: no user_data", .{});
        return;
    };
    const instance: *runtime.Instance = @ptrCast(@alignCast(user_data));

    // Dispatch the message event to onmessage handler
    dispatchMessageEvent(instance, msg);
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
    std.log.debug("dispatchMessageEvent: called", .{});

    // Get internal state with GlobalHandle and isolate
    const internal = getInternal(instance) orelse {
        std.log.debug("dispatchMessageEvent: no internal state", .{});
        return;
    };

    // Get isolate and V8 context
    const isolate = internal.isolate orelse {
        std.log.debug("dispatchMessageEvent: no isolate", .{});
        return;
    };
    const ctx = internal.ctx orelse {
        std.log.debug("dispatchMessageEvent: no ctx", .{});
        return;
    };
    const v8_context: *v8_engine.ffi.Context = ctx.getEngineContextAs(v8_engine.ffi.Context) orelse {
        std.log.debug("dispatchMessageEvent: no v8_context", .{});
        return;
    };

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

    // Create HandleScope for V8 handle allocation
    // This is CRITICAL when called from a timer callback where there's no
    // existing HandleScope (unlike when called from JavaScript execution).
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(isolate);
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Verify we have a valid context, enter if needed
    const current_context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate);
    const need_enter_context = (current_context == null) or (current_context != v8_context);
    if (need_enter_context) {
        v8_engine.ffi.v8_Context_Enter(v8_context);
    }
    defer if (need_enter_context) {
        v8_engine.ffi.v8_Context_Exit(v8_context);
    };

    // Get the message data - check if it's a JSON string from worker
    // The worker sends JSON-serialized messages for cross-isolate safety
    var v8_data: ?*v8_engine.ffi.Value = null;

    std.log.debug("dispatchMessageEvent: msg.data.type = {}", .{msg.data.type});

    // Check the serialized value type
    if (msg.data.type == .primitive) {
        std.log.debug("dispatchMessageEvent: primitive type, checking for string", .{});
        switch (msg.data.data.primitive) {
            .string => |json_str| {
                std.log.debug("dispatchMessageEvent: JSON string ({d} bytes): {s}", .{ json_str.len, json_str[0..@min(json_str.len, 200)] });
                // JSON string from worker - parse it in main context
                v8_data = v8_engine.ffi.v8_JSON_Parse_FromBuffer(
                    v8_context,
                    json_str.ptr,
                    @intCast(json_str.len),
                );
                if (v8_data == null) {
                    std.log.warn("Worker.dispatchMessageEvent: JSON.parse failed for: {s}", .{json_str});
                } else {
                    std.log.debug("dispatchMessageEvent: JSON.parse succeeded", .{});
                }
            },
            else => |other| {
                std.log.debug("dispatchMessageEvent: primitive is not string, is {}", .{other});
            },
        }
    } else {
        std.log.debug("dispatchMessageEvent: not a primitive type", .{});
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
        event_state.own.data = runtime.JSValue.fromAnyopaque(@ptrCast(deserialized));

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
    // For JSON-parsed values, we store the V8 Value pointer
    var event_state = message_event.getState(MessageEvent.State);
    event_state.own.data = runtime.JSValue.fromHandle(@ptrCast(v8_data));

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
    std.log.debug("invokeMessageListeners: starting", .{});

    // Import EventTarget impl to access event listener list
    const EventTargetImpl = @import("EventTarget.zig");
    const CallbackWrapper = v8_engine.CallbackWrapper;

    // Step 1: Invoke registered "message" event listeners (from addEventListener)
    if (EventTargetImpl.getInternalState(instance)) |et_internal| {
        const listeners = et_internal.getEventListenerList();
        std.log.debug("invokeMessageListeners: found {d} event listeners", .{listeners.len});
        for (listeners) |listener| {
            // Check if listener is for "message" events and not removed
            if (std.mem.eql(u8, listener.type.asSlice(), "message") and !listener.removed) {
                std.log.debug("invokeMessageListeners: found message listener", .{});
                // listener.callback is actually a *CallbackWrapper
                if (listener.callback) |callback_instance| {
                    const callback_wrapper: *CallbackWrapper = @ptrCast(@alignCast(callback_instance));
                    _ = callback_wrapper.call1(v8_context, @ptrCast(v8_event));
                }
            }
        }
    } else {
        std.log.debug("invokeMessageListeners: no EventTarget internal state", .{});
    }

    // Step 2: Invoke the onmessage handler if set
    std.log.debug("invokeMessageListeners: checking onmessage_handle: {}", .{internal.onmessage_handle != null});
    if (internal.onmessage_handle) |onmessage_global| {
        // Retrieve Local handle from Global handle
        const local_value = onmessage_global.get(isolate) orelse {
            std.log.warn("Worker.invokeMessageListeners: Failed to get Local from GlobalHandle", .{});
            return;
        };

        // Verify it's a function
        if (!v8_engine.ffi.v8_Value_IsFunction(@ptrCast(local_value))) {
            std.log.warn("Worker.invokeMessageListeners: onmessage is not a function", .{});
            return;
        }
        const function: *v8_engine.ffi.Function = @ptrCast(local_value);

        // Call the V8 function with the MessageEvent as argument
        const undefined_recv = v8_engine.ffi.v8_Undefined(isolate);
        var args = [_]*v8_engine.ffi.Value{@ptrCast(v8_event)};
        _ = v8_engine.ffi.v8_Function_Call(function, v8_context, @ptrCast(undefined_recv), 1, &args);
    }
}

/// Operation: terminate
///
/// Spec: HTML Standard § 10.2.3.1 terminate()
/// "The terminate() method, when invoked, must cause the terminate a worker
/// algorithm to be run on the worker with which the object is associated."
pub fn call_terminate(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    if (state.own._internal) |internal_ptr| {
        // Mark as terminated
        const internal = @constCast(internal_ptr);
        internal.terminated = true;
        if (internal.dedicated_worker) |worker| {
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
pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.terminated) {
            return; // Worker is terminated, ignore message
        }
        if (internal.dedicated_worker) |worker| {
            // Post message to the dedicated worker
            // The dedicated worker will handle serialization and dispatch
            // Convert JSValue to anyopaque for the internal API
            const message_ptr = message.toAnyopaque() orelse return error.TypeError;
            const transfer_ptr = transfer.toAnyopaque() orelse return error.TypeError;
            try worker.postMessage(message_ptr, transfer_ptr);
        }
    }
}
