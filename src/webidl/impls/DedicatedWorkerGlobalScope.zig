//! Implementation for DedicatedWorkerGlobalScope interface
//!
//! Spec: HTML Standard § 10.2.3.2 The DedicatedWorkerGlobalScope interface
//! https://html.spec.whatwg.org/#dedicatedworkerglobalscope
//!
//! The global scope object inside a dedicated worker. Extends WorkerGlobalScope
//! with dedicated worker-specific functionality like postMessage and close.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const DedicatedWorkerGlobalScope = interfaces.DedicatedWorkerGlobalScope;

// Import workers infrastructure
const html_core = @import("html_core");
const workers = html_core.workers;
const DedicatedWorker = workers.DedicatedWorker;

// Import structured clone for message passing
const structured_clone = html_core.structured_clone;

pub const State = DedicatedWorkerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
    PostMessageFailed,
    WorkerClosed,
};

/// Internal state for DedicatedWorkerGlobalScope implementation
///
/// Contains a reference to the backing DedicatedWorker and worker-specific state.
pub const InternalState = struct {
    /// Reference to the dedicated worker (not owned)
    dedicated_worker: ?*DedicatedWorker = null,

    /// Worker name
    name: []const u8 = "",

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        // We don't own the dedicated_worker, so don't deinit it
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

/// Initialize with a backing dedicated worker
pub fn initWithWorker(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    dedicated_worker: *DedicatedWorker,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state
    const internal_state = try allocator.create(InternalState);
    internal_state.* = .{
        .dedicated_worker = dedicated_worker,
        .name = dedicated_worker.getName(),
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
/// Spec: HTML Standard § 10.2.3.2
/// "The name attribute must return the DedicatedWorkerGlobalScope object's name."
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return runtime.DOMString.initInterned(internal.name);
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for onrtctransform
pub fn get_onrtctransform(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onrtctransform;
}

/// Getter for onmessage
pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onmessage;
}

/// Getter for onmessageerror
pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onmessageerror;
}

/// Setter for onrtctransform
pub fn set_onrtctransform(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onrtctransform = value;
}

/// Setter for onmessage
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onmessage = value;
}

/// Setter for onmessageerror
pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onmessageerror = value;
}

/// Operation: requestAnimationFrame
///
/// Spec: HTML Standard § 10.10.3
/// Request animation frame in worker context (for OffscreenCanvas).
/// Returns a handle that can be used with cancelAnimationFrame.
pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: callbacks.FrameRequestCallback) anyerror!u32 {
    _ = instance;
    _ = callback;
    // Animation frames in workers require OffscreenCanvas support
    // For now, return a dummy handle
    return 0;
}

/// Operation: cancelAnimationFrame
///
/// Spec: HTML Standard § 10.10.3
/// Cancel a previously requested animation frame.
pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) anyerror!void {
    _ = instance;
    _ = handle;
    // Animation frames in workers require OffscreenCanvas support
}

/// Operation: close
///
/// Spec: HTML Standard § 10.2.3.2 close()
/// "The close() method, when invoked, must run these steps:
/// 1. Discard any tasks that have been added to this's relevant agent's event loop's task queues.
/// 2. Set this's closing flag to true."
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.dedicated_worker) |worker| {
            worker.close();
        }
    }
}

/// Operation: postMessage
///
/// Spec: HTML Standard § 10.2.3.2 postMessage(message, transfer)
/// Posts a message from the worker to the outside (to the owner).
///
/// "The postMessage(message, transfer) and postMessage(message, options) methods
/// on DedicatedWorkerGlobalScope objects act as if, when invoked, it immediately
/// invoked the respective postMessage(message, transfer) and postMessage(message, options)
/// methods on the port that the DedicatedWorkerGlobalScope object's implicit port is
/// entangled with, with the same arguments."
pub fn call_postMessage(instance: *runtime.Instance, message: v8.JSValue, transfer: *const anyopaque) anyerror!void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.dedicated_worker) |worker| {
            try worker.postMessage(message, transfer);
        }
    }
}

// ============================================================================
// MessageEvent Dispatch
// ============================================================================

/// Dispatch a MessageEvent to this DedicatedWorkerGlobalScope
///
/// This is called by the dedicated worker's inside port handler when a message
/// arrives from the main thread.
///
/// Spec: HTML Standard § 10.2.3
/// "Queue a global task on the messaging task source... fire an event named
/// message at the DedicatedWorkerGlobalScope object."
pub fn dispatchMessageEvent(instance: *runtime.Instance, serialized_data: *structured_clone.SerializedValue, origin: ?[]const u8) anyerror!void {
    const state = instance.getState(State);
    const MessageEvent = interfaces.MessageEvent;

    // Deserialize the message data
    const deserialized = structured_clone.structuredDeserialize(
        state.own._internal.?.allocator,
        serialized_data,
    ) catch {
        // If deserialization fails, we should fire 'messageerror' instead
        // For now, just return error
        return error.DeserializationFailed;
    };

    // Create MessageEventInit dictionary
    const init_dict = dictionaries.MessageEventInit{
        .base = .{
            .bubbles = false,
            .cancelable = false,
            .composed = false,
        },
        .data = @ptrCast(deserialized),
        .origin = origin orelse "",
        .lastEventId = null,
        .source = null,
        .ports = null,
    };

    // Create MessageEvent
    var event = try MessageEvent.call_constructor(
        state.own._internal.?.allocator,
        instance.ctx,
        runtime.DOMString.initInterned("message"),
        .{ .was_passed = true, .value = init_dict },
    );
    defer runtime.Instance.deinit(event);

    // Get the onmessage handler and invoke it
    // TODO: Invoke the EventHandler callback with the event
    // This requires the runtime to support callback invocation
    // For now, the event is created but not dispatched to JavaScript
    //
    // In a full implementation:
    // 1. Get the EventHandler from state.own.onmessage
    // 2. Create a V8 callback invocation
    // 3. Call the handler with the MessageEvent
    //
    // Mark event as used to avoid compiler warning
    event.ctx = event.ctx;
}

/// Wire up the message handler on the dedicated worker's inside port
///
/// This should be called after the DedicatedWorkerGlobalScope is created
/// and linked to its DedicatedWorker.
pub fn setupMessageHandler(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.dedicated_worker) |worker| {
            // Store the instance pointer for use in the callback
            // The callback will dispatch MessageEvent to this scope
            worker.setInsideMessageHandler(struct {
                fn handleMessage(w: *DedicatedWorker, msg: *workers.message_channel.QueuedMessage) void {
                    _ = w;
                    // TODO: Get the instance from w and call dispatchMessageEvent
                    // This requires storing the instance reference in the worker
                    _ = msg;
                }
            }.handleMessage);
        }
    }
}
