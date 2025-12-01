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
/// - Event handlers stored as WebIDL callbacks
pub const InternalState = struct {
    /// Backing implementation from streams internal
    internal_port: *InternalMessagePort,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
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
    };

    // Store internal state in instance
    var state = instance.getState(State);
    state.own._internal = internal_state;

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
    };

    // Store internal state in instance
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

/// Setter for onmessage
/// Spec: § 9.3.2.1 Setting onmessage implicitly calls start()
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onmessage = value;

    // Per spec, setting onmessage implicitly enables the port's message queue
    if (state.own._internal) |internal| {
        internal.internal_port.enableQueue();
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
        internal.internal_port.enableQueue();
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
/// Spec: § 9.3.2.1 postMessage(message, transfer)
///
/// Posts a message to the entangled port. For Streams transfer, we use
/// simplified messages with type and value.
pub fn call_postMessage(instance: *runtime.Instance, message: *const anyopaque, transfer: *const anyopaque) anyerror!void {
    _ = transfer; // Transfer semantics simplified for now

    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // For now, treat message as a JSValue pointer
        // In a full implementation, this would involve structured clone
        // Convert pointer to int for null check (non-null pointers can't be compared to 0)
        const msg_addr = @intFromPtr(message);
        const msg_value = if (msg_addr != 0)
            JSValue{ .object = {} } // Simplified: treat as object
        else
            JSValue.undefined_value();

        internal.internal_port.postMessage("chunk", msg_value) catch |err| {
            return switch (err) {
                error.PortClosed => ImplError.PortClosed,
                error.NotEntangled => ImplError.NotEntangled,
                else => ImplError.OutOfMemory,
            };
        };
    }
}
