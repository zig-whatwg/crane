//! Implementation for MessageChannel interface
//!
//! Spec: HTML Standard § 9.3.1 Message channels
//! https://html.spec.whatwg.org/#message-channels
//!
//! A MessageChannel object has an associated port 1 and an associated port 2,
//! both MessagePort objects. On creation, the channel's two ports are entangled.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const MessageChannel = interfaces.MessageChannel;
const MessagePortInterface = interfaces.MessagePort;

// Import streams internal for MessagePort pair creation
const message_port = @import("streams_internal");
const createMessagePortPair = message_port.createMessagePortPair;

// Import MessagePort impl for initialization
const MessagePortImpl = @import("MessagePort.zig");

pub const State = MessageChannel.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

/// Internal state for MessageChannel implementation
///
/// Stores ownership of the internal MessagePort pair.
/// The WebIDL MessagePort instances (port1, port2) are stored in State.
pub const InternalState = struct {
    /// Allocator used for this state
    allocator: std.mem.Allocator,

    /// Flag indicating if ports have been created
    initialized: bool,
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

    // Create internal state
    const internal_state = try allocator.create(InternalState);
    internal_state.* = .{
        .allocator = allocator,
        .initialized = false,
    };

    // Store internal state in instance
    var state = instance.getState(State);
    state.own._internal = internal_state;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);

    // Clean up ports if they exist
    // Note: The ports are runtime.Instance pointers, they manage their own cleanup
    // We don't deinit them here as they may be held by other references

    if (state.own._internal) |internal| {
        internal.allocator.destroy(internal);
    }

    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// Spec: § 9.3.1 MessageChannel()
///
/// Creates a new MessageChannel with two entangled MessagePort objects.
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &MessageChannel.vtable, ctx);
    errdefer deinit(instance);

    var state = instance.getState(State);

    // Create entangled internal MessagePort pair
    const ports = try createMessagePortPair(ctx.allocator);
    errdefer {
        ports[0].deinit();
        ports[1].deinit();
    }

    // Create WebIDL MessagePort instances wrapping the internal ports
    const port1_instance = try MessagePortImpl.initWithInternal(
        ctx.allocator,
        MessagePortInterface.State,
        &MessagePortInterface.vtable,
        ctx,
        ports[0],
    );
    errdefer MessagePortInterface.deinit(port1_instance);

    const port2_instance = try MessagePortImpl.initWithInternal(
        ctx.allocator,
        MessagePortInterface.State,
        &MessagePortInterface.vtable,
        ctx,
        ports[1],
    );
    errdefer MessagePortInterface.deinit(port2_instance);

    // Store ports in state
    state.own.port1 = port1_instance;
    state.own.port2 = port2_instance;

    if (state.own._internal) |internal| {
        internal.initialized = true;
    }

    return instance;
}

/// Getter for port1
/// Spec: The port1 getter steps are to return this's port 1.
pub fn get_port1(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    return state.own.port1;
}

/// Getter for port2
/// Spec: The port2 getter steps are to return this's port 2.
pub fn get_port2(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    return state.own.port2;
}
