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

// The channel the two ports share (its ends may later live on two
// threads), and the hook that makes a MessagePort on an end of it.
const dom = @import("dom");
const port_channels = dom.port_channels;
const message_ports = dom.message_ports;

// A channel keeps the ports it has handed out alive for as long as it lives.
const same_object = @import("same_object.zig");

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

    /// Flag indicating if port1 has been exposed to JavaScript (wrapped in V8)
    /// If true, GC owns the port's lifetime. If false, MessageChannel owns it.
    port1_exposed: bool = false,

    /// Flag indicating if port2 has been exposed to JavaScript (wrapped in V8)
    /// If true, GC owns the port's lifetime. If false, MessageChannel owns it.
    port2_exposed: bool = false,

    /// The exposed ports, kept by the channel's wrapper: `port1` and `port2`
    /// are [SameObject], and the channel's state points at them where V8
    /// cannot see - so a port script reached only through its channel
    /// (`channel.port2.postMessage(...)` with nothing else holding port2) was
    /// collected while the channel lived, and the next `channel.port2` handed
    /// out a freed slot. Blink traces both from MessageChannel::Trace; so does
    /// this (same_object.Traced: an edge, not a root).
    port1_edge: same_object.Traced = .{ .slot = .{ .name = "port1" } },
    port2_edge: same_object.Traced = .{ .slot = .{ .name = "port2" } },
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

    // Handle port cleanup based on whether they were exposed to JavaScript
    //
    // OWNERSHIP MODEL:
    // - When get_port1/get_port2 is called, the port gets wrapped in a V8 object
    //   and cached in the wrapper_cache. At that point, GC owns the port's lifetime.
    // - If a port was NEVER accessed (never exposed to JS), MessageChannel still
    //   owns it and must clean it up to avoid memory leaks.
    //
    // This follows Chromium/Blink's pattern where MessageChannel uses Member<MessagePort>
    // (GC-traced pointers), but we must handle the case where ports are never accessed.
    if (state.own._internal) |internal| {
        if (internal.initialized) {
            // Clean up port1 only if it was never exposed to JavaScript
            if (!internal.port1_exposed) {
                MessagePortInterface.deinit(state.own.port1);
            }
            // Clean up port2 only if it was never exposed to JavaScript
            if (!internal.port2_exposed) {
                MessagePortInterface.deinit(state.own.port2);
            }
        }
        internal.port1_edge.release(instance);
        internal.port2_edge.release(instance);
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

    // "Set this's port 1 to a new MessagePort in this's relevant realm. Set
    // this's port 2 to a new MessagePort in this's relevant realm. Entangle
    // this's port 1 and this's port 2." - two ports on the two ends of a new
    // channel, entangled from the start.
    const channel = try port_channels.Channel.create(ctx.allocator);
    const port1_instance = message_ports.adopt(ctx, channel.end(0)) catch |err| {
        channel.end(1).discard();
        return err;
    };
    errdefer MessagePortInterface.deinit(port1_instance);
    // `adopt` takes the end whatever happens.
    const port2_instance = try message_ports.adopt(ctx, channel.end(1));
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
    // Mark port1 as exposed to JavaScript - GC now owns its lifetime
    if (state.own._internal) |internal| {
        internal.port1_exposed = true;
        if (!internal.port1_edge.drawn) internal.port1_edge.hold(instance, state.own.port1);
    }
    return state.own.port1;
}

/// Getter for port2
/// Spec: The port2 getter steps are to return this's port 2.
pub fn get_port2(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    // Mark port2 as exposed to JavaScript - GC now owns its lifetime
    if (state.own._internal) |internal| {
        internal.port2_exposed = true;
        if (!internal.port2_edge.drawn) internal.port2_edge.hold(instance, state.own.port2);
    }
    return state.own.port2;
}
