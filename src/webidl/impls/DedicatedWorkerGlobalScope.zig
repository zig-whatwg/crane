//! Implementation for DedicatedWorkerGlobalScope interface
//!
//! Spec: HTML Standard § 10.2.3.2 The DedicatedWorkerGlobalScope interface
//! https://html.spec.whatwg.org/#dedicatedworkerglobalscope
//!
//! The global scope object inside a dedicated worker. Extends WorkerGlobalScope
//! with dedicated worker-specific functionality like postMessage and close.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const DedicatedWorkerGlobalScope = interfaces.DedicatedWorkerGlobalScope;
const EventTarget = interfaces.EventTarget;
const MessageEvent = interfaces.MessageEvent;

// Import workers infrastructure
const html_core = @import("html_core");
const workers = html_core.workers;
const DedicatedWorker = workers.DedicatedWorker;

// Import structured clone for message passing
const structured_clone = html_core.structured_clone;

// Import V8 engine for callback invocation
const v8_engine = @import("v8");
const template_registry = v8_engine.template_registry;

// Import EventTarget impl for internal state access
const EventTargetImpl = @import("EventTarget.zig");

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
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.name);
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
pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.dedicated_worker) |worker| {
            const msg_ptr = message.toAnyopaque() orelse return error.TypeError;
            const transfer_ptr = transfer.toAnyopaque() orelse return error.TypeError;
            try worker.postMessage(msg_ptr, transfer_ptr);
        }
    }
}

// ============================================================================
// MessageEvent Dispatch
// ============================================================================

/// Dispatch a MessageEvent to this DedicatedWorkerGlobalScope
///
/// This is called by the dedicated worker's inside port handler when a message
/// arrives from the main thread. Uses the DOM event dispatch algorithm via
/// EventTarget.dispatchEvent.
///
/// Spec: HTML Standard § 10.2.3
/// "Queue a global task on the messaging task source... fire an event named
/// message at the DedicatedWorkerGlobalScope object."
pub fn dispatchMessageEvent(instance: *runtime.Instance, serialized_data: *structured_clone.SerializedValue, origin: ?[]const u8) anyerror!void {
    const state = instance.getState(State);
    const allocator = if (state.own._internal) |internal| internal.allocator else return error.NotInitialized;

    // Deserialize the message data
    const deserialized = structured_clone.structuredDeserialize(
        allocator,
        serialized_data,
    ) catch {
        // If deserialization fails, fire 'messageerror' event instead of 'message'
        // Spec: HTML Standard § 9.3.6.2
        // "If this throws an exception, then fire an event named messageerror at the port"
        dispatchMessageErrorEvent(instance, origin) catch |err| {
            std.log.warn("Failed to dispatch messageerror event: {s}", .{@errorName(err)});
        };
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

    // Create MessageEvent via interface
    const event = try MessageEvent.call_constructor(
        instance.ctx,
        runtime.DOMString.initInterned("message"),
        webidl.Opt(dictionaries.MessageEventInit).passed(init_dict),
    );

    // Set isTrusted and target/currentTarget
    {
        var ev_state = event.getState(MessageEvent.State);
        ev_state.base.own.isTrusted = true;
        ev_state.base.own.target = instance;
        ev_state.base.own.currentTarget = instance;
    }

    // Dispatch via EventTarget.dispatchEvent
    // This invokes all addEventListener-registered listeners
    _ = EventTarget.call_dispatchEvent(instance, event) catch |err| {
        std.log.warn("Failed to dispatch MessageEvent to worker scope: {s}", .{@errorName(err)});
    };

    // Also invoke the legacy onmessage handler if set via IDL attribute
    invokeLegacyOnmessageHandler(instance, event);
}

/// Invoke the legacy onmessage IDL attribute handler
///
/// Per HTML spec, the onXXX IDL event handlers are separate from addEventListener.
/// The onmessage property is stored in state.own.onmessage as an EventHandler
/// (which is a tagged pointer to a GlobalHandle).
fn invokeLegacyOnmessageHandler(instance: *runtime.Instance, event: *runtime.Instance) void {
    const state = instance.getState(State);

    // Get the onmessage handler
    const handler = state.own.onmessage orelse return;

    // Get V8 context from the event's runtime context
    const engine_ctx = event.ctx.engine_ctx orelse return;
    const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return;

    // Create HandleScope
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(v8_isolate);
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Untag the pointer to get the GlobalHandle
    const untagged = v8_engine.pointer_tag.untagPointer(handler);
    if (untagged.tag != .global_handle and untagged.tag != .untagged) {
        return; // Not a V8 callback
    }

    const global_handle = v8_engine.GlobalHandle{ .ptr = @ptrCast(@alignCast(untagged.ptr)) };
    const local_value = global_handle.get(v8_isolate) orelse return;

    if (!v8_engine.ffi.v8_Value_IsFunction(@ptrCast(local_value))) {
        return;
    }
    const function: *v8_engine.ffi.Function = @ptrCast(local_value);

    // Wrap the event as a V8 object
    const v8_event = template_registry.wrapInstanceAsV8Object(
        event,
        "MessageEvent",
        v8_isolate,
        v8_context,
    ) catch return;

    // Call the handler
    const undefined_recv = v8_engine.ffi.v8_Undefined(v8_isolate);
    var args = [_]*v8_engine.ffi.Value{@ptrCast(v8_event)};
    _ = v8_engine.ffi.v8_Function_Call(function, v8_context, @ptrCast(undefined_recv), 1, &args);
}

/// Dispatch a messageerror event to this DedicatedWorkerGlobalScope
///
/// Spec: HTML Standard § 9.3.6.2
/// "If this throws an exception, then fire an event named messageerror at the port,
/// using MessageEvent, with the origin attribute initialized to origin..."
///
/// This is called when structured clone deserialization fails on a received message.
fn dispatchMessageErrorEvent(instance: *runtime.Instance, origin: ?[]const u8) anyerror!void {
    // Create MessageEventInit dictionary for messageerror
    // Per spec, data is undefined for messageerror events
    const init_dict = dictionaries.MessageEventInit{
        .base = .{
            .bubbles = false,
            .cancelable = false,
            .composed = false,
        },
        .data = null, // data is undefined for messageerror
        .origin = origin orelse "",
        .lastEventId = null,
        .source = null,
        .ports = null,
    };

    // Create MessageEvent via interface with type "messageerror"
    const event = try MessageEvent.call_constructor(
        instance.ctx,
        runtime.DOMString.initInterned("messageerror"),
        webidl.Opt(dictionaries.MessageEventInit).passed(init_dict),
    );

    // Set isTrusted and target/currentTarget
    {
        var ev_state = event.getState(MessageEvent.State);
        ev_state.base.own.isTrusted = true;
        ev_state.base.own.target = instance;
        ev_state.base.own.currentTarget = instance;
    }

    // Dispatch via EventTarget.dispatchEvent
    _ = EventTarget.call_dispatchEvent(instance, event) catch |err| {
        std.log.warn("Failed to dispatch messageerror event to worker scope: {s}", .{@errorName(err)});
        return err;
    };

    // Also invoke the legacy onmessageerror handler if set
    invokeLegacyOnmessageerrorHandler(instance, event);
}

/// Invoke the legacy onmessageerror IDL attribute handler
fn invokeLegacyOnmessageerrorHandler(instance: *runtime.Instance, event: *runtime.Instance) void {
    const state = instance.getState(State);

    // Get the onmessageerror handler
    const handler = state.own.onmessageerror orelse return;

    // Get V8 context from the event's runtime context
    const engine_ctx = event.ctx.engine_ctx orelse return;
    const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return;

    // Create HandleScope
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(v8_isolate);
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Untag the pointer to get the GlobalHandle
    const untagged = v8_engine.pointer_tag.untagPointer(handler);
    if (untagged.tag != .global_handle and untagged.tag != .untagged) {
        return; // Not a V8 callback
    }

    const global_handle = v8_engine.GlobalHandle{ .ptr = @ptrCast(@alignCast(untagged.ptr)) };
    const local_value = global_handle.get(v8_isolate) orelse return;

    if (!v8_engine.ffi.v8_Value_IsFunction(@ptrCast(local_value))) {
        return;
    }
    const function: *v8_engine.ffi.Function = @ptrCast(local_value);

    // Wrap the event as a V8 object
    const v8_event = template_registry.wrapInstanceAsV8Object(
        event,
        "MessageEvent",
        v8_isolate,
        v8_context,
    ) catch return;

    // Call the handler
    const undefined_recv = v8_engine.ffi.v8_Undefined(v8_isolate);
    var args = [_]*v8_engine.ffi.Value{@ptrCast(v8_event)};
    _ = v8_engine.ffi.v8_Function_Call(function, v8_context, @ptrCast(undefined_recv), 1, &args);
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
