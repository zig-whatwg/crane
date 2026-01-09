//! Implementation for SharedWorkerGlobalScope interface
//!
//! Spec: HTML Standard § 10.2.4.2 The SharedWorkerGlobalScope interface
//! https://html.spec.whatwg.org/#sharedworkerglobalscope
//!
//! The global scope object inside a shared worker. Extends WorkerGlobalScope
//! with shared worker-specific functionality like the name attribute and
//! connect event.
//!
//! ## Connect Event Flow (HTML Standard § 10.2.4.1 step 17)
//!
//! When a client connects to a SharedWorker:
//! 1. SharedWorker.connect() creates a WorkerPortPair (inside_port + outside_port)
//! 2. The outside_port is returned to the client via SharedWorker.port
//! 3. A "connect" event (MessageEvent) is fired on SharedWorkerGlobalScope
//! 4. The event's ports array contains the inside_port (wrapped as MessagePort)
//! 5. The worker's onconnect handler receives the event and can use the port

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SharedWorkerGlobalScope = interfaces.SharedWorkerGlobalScope;
const MessagePort = interfaces.MessagePort;
const MessageEvent = interfaces.MessageEvent;

// Import MessagePort implementation for creating port instances
const MessagePortImpl = @import("MessagePort.zig");
const MessageEventImpl = @import("MessageEvent.zig");

// Import workers infrastructure
const html_core = @import("html_core");
const workers = html_core.workers;
const InternalSharedWorker = workers.SharedWorker;
const SharedWorkerConnection = workers.SharedWorkerConnection;
const WorkerPort = workers.WorkerPort;

// Import streams internal MessagePort for bridging
const streams_internal = @import("streams_internal");
const InternalMessagePort = streams_internal.MessagePort;

pub const State = SharedWorkerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
    WorkerClosed,
};

/// Internal state for SharedWorkerGlobalScope implementation
///
/// Contains a reference to the backing SharedWorker.
pub const InternalState = struct {
    /// Reference to the shared worker (not owned)
    shared_worker: ?*InternalSharedWorker = null,

    /// Worker name
    name: []const u8 = "",

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        // We don't own the shared_worker, so don't deinit it
        _ = self;
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

/// Initialize with a backing shared worker
pub fn initWithWorker(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    shared_worker: *InternalSharedWorker,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state
    const internal_state = try allocator.create(InternalState);
    internal_state.* = .{
        .shared_worker = shared_worker,
        .name = shared_worker.getName(),
        .allocator = allocator,
    };

    // Store internal state
    var state = instance.getState(State);
    state.own._internal = internal_state;

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

/// Getter for name
///
/// Spec: HTML Standard § 10.2.4.2
/// "The name attribute must return the SharedWorkerGlobalScope object's name."
/// This is the name provided in the SharedWorker constructor.
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.name);
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for onconnect
///
/// Spec: HTML Standard § 10.2.4.2
/// "The onconnect attribute is an event handler IDL attribute whose event handler
/// event type is connect."
/// This event fires when a new context connects to the shared worker.
pub fn get_onconnect(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onconnect;
}

/// Setter for onconnect
pub fn set_onconnect(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onconnect = value;
}

/// Operation: close
///
/// Spec: HTML Standard § 10.2.4.2 close()
/// "The close() method, when invoked, must run these steps:
/// 1. Discard any tasks that have been added to this's relevant agent's event loop's task queues.
/// 2. Set this's closing flag to true."
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.shared_worker) |worker| {
            worker.close();
        }
    }
}

/// Fire a connect event for a new connection
///
/// Spec: HTML Standard § 10.2.4.1 step 17
/// "queue a global task on the DOM manipulation task source given
/// workerGlobalScope to fire an event named connect at workerGlobalScope,
/// using MessageEvent, with the data attribute initialized to the empty string,
/// the ports attribute initialized to a new frozen array containing inside port..."
///
/// This is called when a new client connects to the shared worker.
/// The inside port from the connection is passed in the event's ports array.
pub fn fireConnectEvent(instance: *runtime.Instance, connection: *SharedWorkerConnection) !void {
    const allocator = instance.ctx.allocator;
    const state = instance.getState(State);

    // Get the inside port from the connection
    const worker_port = connection.getInsidePort() orelse {
        return; // No port to pass
    };

    // Always enable the port's queue so messages aren't lost
    worker_port.start();

    // Create a WebIDL MessagePort instance wrapping the inside WorkerPort
    // This bridges between the workers infrastructure and the WebIDL interface
    const message_port_instance = try createMessagePortFromWorkerPort(
        allocator,
        instance.ctx,
        worker_port,
    );

    // Create a MessageEvent for the connect event
    // Spec: "fire an event named connect...using MessageEvent"
    const message_event = try createConnectEvent(
        allocator,
        instance.ctx,
        message_port_instance,
    );

    // Check if onconnect handler is set and invoke it
    const handler = state.own.onconnect;
    if (handler != null and handler.? != null) {
        // Invoke the onconnect handler with the MessageEvent
        try invokeConnectHandler(instance, handler.?.?, message_event);
    }

    // Note: In a full implementation, we would also dispatch the event
    // through the DOM event system. For now, direct handler invocation
    // is sufficient for the common SharedWorker usage pattern.
}

/// Create a WebIDL MessagePort instance from a WorkerPort
///
/// This bridges between the workers infrastructure (WorkerPort) and
/// the WebIDL MessagePort interface that JavaScript code expects.
fn createMessagePortFromWorkerPort(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    worker_port: *WorkerPort,
) !*runtime.Instance {
    // Create an internal MessagePort
    const internal_port = try InternalMessagePort.init(allocator);
    errdefer internal_port.deinit();

    // Set up message handler on WorkerPort to forward messages
    // The WorkerPort dispatches messages to its handler when received
    worker_port.setOnMessage(struct {
        fn onMessage(port: *WorkerPort, msg: *workers.QueuedMessage, context: ?*anyopaque) void {
            _ = port;
            _ = msg;
            // Forward message to the InternalMessagePort's onmessage handler
            if (context) |ctx_ptr| {
                const target_port: *InternalMessagePort = @ptrCast(@alignCast(ctx_ptr));
                // Dispatch queued messages if queue is enabled
                if (target_port.queue_enabled) {
                    target_port.dispatchQueuedMessages() catch {};
                }
            }
        }
    }.onMessage, internal_port);

    // Create the WebIDL MessagePort instance with the internal port
    const port_instance = try MessagePortImpl.initWithInternal(
        allocator,
        MessagePort.State,
        &MessagePort.vtable,
        ctx,
        internal_port,
    );

    return port_instance;
}

/// Create a MessageEvent for the "connect" event
///
/// Spec: HTML Standard § 10.2.4.1 step 17
/// - type: "connect"
/// - data: "" (empty string)
/// - origin: "" (empty string for same-origin)
/// - ports: frozen array containing the inside port
fn createConnectEvent(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    port_instance: *runtime.Instance,
) !*runtime.Instance {
    // Create MessageEvent instance
    const event_instance = try MessageEventImpl.init(
        allocator,
        MessageEvent.State,
        &MessageEvent.vtable,
        ctx,
    );
    errdefer MessageEventImpl.deinit(event_instance);

    const event_state = event_instance.getState(MessageEvent.State);

    // Set event type to "connect"
    event_state.base.own.type = try runtime.DOMString.initDupe(allocator, "connect");

    // Set timestamps and flags per spec
    event_state.base.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(std.time.milliTimestamp()));
    event_state.base.own.isTrusted = true; // Trusted event (created by UA)
    event_state.base.own.target = null;
    event_state.base.own.srcElement = null;
    event_state.base.own.currentTarget = null;
    event_state.base.own.eventPhase = 0; // NONE

    // Connect events do not bubble and are not cancelable
    event_state.base.own.bubbles = false;
    event_state.base.own.cancelable = false;
    event_state.base.own.composed = false;
    event_state.base.own.cancelBubble = false;
    event_state.base.own.returnValue = true;
    event_state.base.own.defaultPrevented = false;

    // MessageEvent-specific properties
    // data: "" (empty string per spec)
    event_state.own.data = runtime.JSValue{ .string = runtime.DOMString.initInterned("") };
    // origin: "" (same-origin worker)
    event_state.own.origin = "";
    // lastEventId: "" (not used for connect events)
    event_state.own.lastEventId = runtime.DOMString.initEmpty();
    // source: null (not applicable for SharedWorker connect)
    event_state.own.source = null;

    // Store the port instance for the ports getter
    // The ports array will contain the inside_port
    // Store the port reference in internal state for later retrieval
    if (event_state.own._internal) |internal| {
        internal.message_data = .{ .any = @ptrCast(port_instance) };
    }

    return event_instance;
}

/// Invoke the onconnect handler with the MessageEvent
///
/// This calls the JavaScript handler function with the event object.
/// Uses direct V8 function call since we're in the worker context.
fn invokeConnectHandler(
    _: *runtime.Instance,
    handler: *const anyopaque,
    event: *runtime.Instance,
) !void {
    // Import V8 FFI for direct function calls
    const v8 = @import("v8");

    // Get the V8 context (instance not needed since we use current isolate/context)
    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
    const v8_context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

    // The handler is stored as a GlobalHandle to a V8 Function
    // We need to get the Local handle and call it
    const handler_global: *v8.GlobalHandle = @ptrCast(@alignCast(@constCast(handler)));
    const local_value = handler_global.get(isolate) orelse {
        return error.InvalidHandler;
    };

    // Verify it's a function
    if (!v8.ffi.v8_Value_IsFunction(@ptrCast(local_value))) {
        return error.NotAFunction;
    }
    const function: *v8.ffi.Function = @ptrCast(local_value);

    // Wrap the MessageEvent instance as a V8 object
    const v8_event = v8.template_registry.wrapInstanceAsV8Object(
        isolate,
        v8_context,
        event,
    ) orelse return error.WrapFailed;

    // Call the handler with the event as the argument
    // The 'this' is undefined per spec for event handlers
    const undefined_recv = v8.ffi.v8_Undefined(isolate);
    var args = [_]*v8.ffi.Value{@ptrCast(v8_event)};
    _ = v8.ffi.v8_Function_Call(function, v8_context, @ptrCast(undefined_recv), 1, &args);
}

/// Get the inside port for a connection (for event dispatch)
pub fn getInsidePort(_: *runtime.Instance, connection: *SharedWorkerConnection) ?*WorkerPort {
    return connection.getInsidePort();
}
