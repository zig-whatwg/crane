//! Implementation for MessagePort interface
//!
//! Spec: HTML Standard § 9.3.2 Message ports
//! https://html.spec.whatwg.org/#message-ports
//!
//! This implementation bridges the WebIDL interface to the streams internal
//! MessagePort implementation for cross-realm stream transfer support.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const MessagePort = interfaces.MessagePort;

// V8 engine for event handler invocation
const v8_engine = @import("v8");

// Import streams internal MessagePort for implementation
const message_port = @import("streams_internal");
const InternalMessagePort = message_port.MessagePort;
// Import JSValue from streams common
const streams_common = @import("streams_common");
const JSValue = streams_common.JSValue;

pub const State = MessagePort.State;

pub const ImplError = error{
    NotImplemented,
    PortClosed,
    NotEntangled,
    OutOfMemory,
};

/// Internal state for MessagePort implementation
///
/// Contains:
/// - Pointer to streams internal MessagePort for actual message passing
/// - Reference to the WebIDL instance for event dispatch
/// - Allocator for memory management
/// - V8 GlobalHandle for onmessage event handler
pub const InternalState = struct {
    /// Backing implementation from streams internal
    internal_port: *InternalMessagePort,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    /// Reference to the WebIDL MessagePort instance for event dispatch
    /// This allows us to dispatch events to the correct target when
    /// messages are received from the entangled port
    port_instance: ?*runtime.Instance = null,

    /// V8 GlobalHandle for onmessage event handler
    /// Stored separately for direct V8 invocation after event dispatch
    onmessage_handle: v8_engine.OptionalGlobalHandle = null,

    pub fn deinit(self: *InternalState) void {
        // Dispose V8 GlobalHandle if set
        v8_engine.disposeOptionalGlobalHandle(&self.onmessage_handle);
        self.internal_port.deinit();
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
    errdefer runtime.Instance.deinit(instance);

    // Create internal MessagePort
    const internal_port = try InternalMessagePort.init(allocator);
    errdefer internal_port.deinit();

    // Create internal state
    const internal_state = try allocator.create(InternalState);
    internal_state.* = .{
        .internal_port = internal_port,
        .allocator = allocator,
        .port_instance = instance, // Store reference for event dispatch
    };

    // Store internal state in instance
    var state = instance.getState(State);
    state.own._internal = internal_state;

    // Link internal port back to WebIDL instance for message delivery
    internal_port.webidl_instance = instance;

    return instance;
}

/// Initialize instance with existing internal MessagePort
/// Used by MessageChannel to create entangled ports
pub fn initWithInternal(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    internal_port: *InternalMessagePort,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state with provided port
    const internal_state = try allocator.create(InternalState);
    internal_state.* = .{
        .internal_port = internal_port,
        .allocator = allocator,
        .port_instance = instance, // Store reference for event dispatch
    };

    // Store internal state in instance
    var state = instance.getState(State);
    state.own._internal = internal_state;

    // Link internal port back to WebIDL instance for message delivery
    internal_port.webidl_instance = instance;

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

/// Get internal MessagePort (for streams integration)
pub fn getInternalPort(instance: *runtime.Instance) ?*InternalMessagePort {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.internal_port;
    }
    return null;
}

/// Getter for onclose
pub fn get_onclose(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onclose;
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

/// Setter for onclose
pub fn set_onclose(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onclose = value;
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

/// Setter for onmessage
/// Spec: § 9.3.2.1 Setting onmessage implicitly calls start()
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onmessage = value;

    // Per spec, setting onmessage implicitly enables the port's message queue
    if (state.own._internal) |internal| {
        // Extract and store the V8 GlobalHandle for direct invocation
        v8_engine.disposeOptionalGlobalHandle(&internal.onmessage_handle);
        internal.onmessage_handle = extractEventHandler(@ptrCast(value));

        const was_enabled = internal.internal_port.queue_enabled;
        internal.internal_port.enableQueue();

        // Flush any pending messages now that the queue is enabled
        if (!was_enabled) {
            flushPendingMessages(instance, internal);
        }
    }
}

/// Setter for onmessageerror
pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onmessageerror = value;
}

/// Operation: start
/// Spec: § 9.3.2.5 start() method
///
/// Enables the port's message queue. Messages received while the queue
/// is disabled are queued and will be dispatched when start() is called.
pub fn call_start(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        const was_enabled = internal.internal_port.queue_enabled;
        internal.internal_port.enableQueue();

        // Flush any pending messages now that the queue is enabled
        if (!was_enabled) {
            flushPendingMessages(instance, internal);
        }
    }
}

/// Operation: close
/// Spec: § 9.3.2.6 close() method
///
/// Disconnects the port so it is no longer active.
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.internal_port.close();
    }
}

/// Operation: postMessage
/// Spec: HTML Standard § 9.4.1 postMessage(message, transfer)
///
/// Posts a message to the entangled port. The message is delivered
/// asynchronously by creating a MessageEvent and dispatching it
/// to the entangled port's message event target.
pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
    _ = transfer; // TODO: Implement transfer semantics

    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    const internal_port = internal.internal_port;

    // Step 2: Get the entangled port
    const entangled_port = internal_port.entangled_port orelse {
        // Not entangled - silently return per spec
        return;
    };

    // Get the target port's WebIDL instance for event dispatch
    const target_instance: *runtime.Instance = if (entangled_port.webidl_instance) |inst|
        @ptrCast(@alignCast(inst))
    else {
        // No WebIDL instance - fall back to internal queue for streams
        const msg_value = convertToStreamsJSValue(message, internal.allocator) catch {
            return ImplError.OutOfMemory;
        };
        internal_port.postMessage("chunk", msg_value) catch |err| {
            return switch (err) {
                error.PortClosed => ImplError.PortClosed,
                error.NotEntangled => ImplError.NotEntangled,
                else => ImplError.OutOfMemory,
            };
        };
        return;
    };

    // Check if target port's queue is enabled
    if (entangled_port.queue_enabled) {
        // Queue is enabled - deliver message now
        try deliverMessage(target_instance, message);
    } else {
        // Queue is disabled - store message for later delivery
        // Clone the message and heap-allocate it for storage
        const cloned_ptr = try internal.allocator.create(runtime.JSValue);
        errdefer internal.allocator.destroy(cloned_ptr);
        cloned_ptr.* = try message.clone(internal.allocator);
        try entangled_port.queuePendingMessage(@ptrCast(cloned_ptr));
    }
}

/// Convert runtime.JSValue to streams internal JSValue
fn convertToStreamsJSValue(message: runtime.JSValue, allocator: std.mem.Allocator) !JSValue {
    return switch (message) {
        .undefined => JSValue.undefined_value(),
        .null => JSValue{ .null = {} },
        .boolean => |b| JSValue{ .boolean = b },
        .number => |n| JSValue{ .number = n },
        .string => |s| JSValue{ .string = s.data },
        .handle => |h| try JSValue.fromEnginePtr(allocator, h.ptr),
        .instance => JSValue{ .object = {} },
    };
}

/// Deliver a message to a port by creating and dispatching a MessageEvent
///
/// Spec: HTML Standard § 9.4.1 step 6 (task steps)
/// 1. Create a MessageEvent with the data
/// 2. Dispatch the event to the port
/// 3. Invoke legacy onmessage handler if set
fn deliverMessage(port_instance: *runtime.Instance, data: runtime.JSValue) !void {
    const allocator = port_instance.ctx.allocator;

    // Create MessageEvent with the data
    const MessageEventImpl = @import("MessageEvent.zig");
    const event = try MessageEventImpl.createPortMessageEvent(allocator, port_instance.ctx, data);
    errdefer interfaces.Event.deinit(event);

    // Dispatch the event to the port via EventTarget (invokes addEventListener listeners)
    const event_dispatch = @import("dom").event_dispatch;
    _ = try event_dispatch.dispatch(event, port_instance, false, null);

    // After dispatchEvent, invoke the legacy onmessage handler if set
    // The dispatchEvent handles listeners registered via addEventListener,
    // but we need to separately handle the legacy onXXX IDL attribute handler
    const state = port_instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.onmessage_handle) |onmessage_global| {
            invokeLegacyOnmessageHandler(port_instance, event, onmessage_global);
        }
    }
}

/// Invoke the legacy onmessage IDL attribute handler
///
/// Per HTML spec, the onXXX IDL event handlers are separate from addEventListener.
/// The onmessage property stores a GlobalHandle to a JavaScript function.
/// This function is called after EventTarget.dispatchEvent has handled all
/// addEventListener-registered listeners.
fn invokeLegacyOnmessageHandler(
    port_instance: *runtime.Instance,
    event: *runtime.Instance,
    onmessage_global: v8_engine.GlobalHandle,
) void {
    _ = port_instance; // For future use

    // Get the V8 isolate and context
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse {
        std.log.warn("MessagePort.invokeLegacyOnmessageHandler: No current isolate", .{});
        return;
    };
    const v8_context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        std.log.warn("MessagePort.invokeLegacyOnmessageHandler: No current context", .{});
        return;
    };

    // Create HandleScope for V8 operations - required when calling V8 APIs
    // that create Local handles outside of a V8-initiated callback
    const scope = v8_engine.ffi.v8_HandleScope_New(isolate);
    defer v8_engine.ffi.v8_HandleScope_Dispose(scope);

    // Retrieve Local handle from Global handle
    const local_value = onmessage_global.get(isolate) orelse {
        std.log.warn("MessagePort.invokeLegacyOnmessageHandler: Failed to get Local from GlobalHandle", .{});
        return;
    };

    // Verify it's a function
    if (!v8_engine.ffi.v8_Value_IsFunction(@ptrCast(local_value))) {
        std.log.warn("MessagePort.invokeLegacyOnmessageHandler: onmessage is not a function", .{});
        return;
    }
    const function: *v8_engine.ffi.Function = @ptrCast(local_value);

    // Wrap the event as a V8 object
    const v8_event = v8_engine.template_registry.wrapInstanceAsV8Object(
        event,
        "MessageEvent",
        isolate,
        v8_context,
    ) catch |err| {
        std.log.warn("MessagePort: Failed to wrap MessageEvent as V8 object: {s}", .{@errorName(err)});
        return;
    };

    // Call the V8 function with the MessageEvent as argument
    const undefined_recv = v8_engine.ffi.v8_Undefined(isolate);
    var args = [_]*v8_engine.ffi.Value{@ptrCast(v8_event)};
    _ = v8_engine.ffi.v8_Function_Call(function, v8_context, @ptrCast(undefined_recv), 1, &args);
}

/// Flush all pending messages from the queue
/// Called when the queue is enabled (via start() or set_onmessage)
fn flushPendingMessages(instance: *runtime.Instance, internal: *InternalState) void {
    const internal_port = internal.internal_port;

    // Deliver all pending messages
    while (internal_port.popPendingMessage()) |pending_ptr| {
        // Cast back from *anyopaque to *runtime.JSValue
        const pending_msg: *runtime.JSValue = @ptrCast(@alignCast(pending_ptr));
        defer {
            // Free the cloned message after delivery
            pending_msg.deinit(internal.allocator);
            internal.allocator.destroy(pending_msg);
        }

        deliverMessage(instance, pending_msg.*) catch |err| {
            // Log error but continue processing queue
            std.log.err("Failed to deliver pending message: {s}", .{@errorName(err)});
        };
    }
}
