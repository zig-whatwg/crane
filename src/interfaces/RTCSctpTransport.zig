//! Generated from: webrtc.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCSctpTransportImpl = @import("../impls/RTCSctpTransport.zig");
const EventTarget = @import("EventTarget.zig");

pub const RTCSctpTransport = struct {
    pub const Meta = struct {
        pub const name = "RTCSctpTransport";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            transport: RTCDtlsTransport = undefined,
            state: RTCSctpTransportState = undefined,
            maxMessageSize: f64 = undefined,
            maxChannels: ?u16 = null,
            onstatechange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCSctpTransport, .{
        .deinit_fn = &deinit_wrapper,

        .get_maxChannels = &get_maxChannels,
        .get_maxMessageSize = &get_maxMessageSize,
        .get_onstatechange = &get_onstatechange,
        .get_state = &get_state,
        .get_transport = &get_transport,

        .set_onstatechange = &set_onstatechange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        RTCSctpTransportImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RTCSctpTransportImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_transport(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCSctpTransportImpl.get_transport(state);
    }

    pub fn get_state(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCSctpTransportImpl.get_state(state);
    }

    pub fn get_maxMessageSize(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return RTCSctpTransportImpl.get_maxMessageSize(state);
    }

    pub fn get_maxChannels(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCSctpTransportImpl.get_maxChannels(state);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCSctpTransportImpl.get_onstatechange(state);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCSctpTransportImpl.set_onstatechange(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return RTCSctpTransportImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCSctpTransportImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCSctpTransportImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCSctpTransportImpl.call_removeEventListener(state, type_, callback, options);
    }

};
