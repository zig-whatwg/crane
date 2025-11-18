//! Generated from: webrtc.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCDtlsTransportImpl = @import("../impls/RTCDtlsTransport.zig");
const EventTarget = @import("EventTarget.zig");

pub const RTCDtlsTransport = struct {
    pub const Meta = struct {
        pub const name = "RTCDtlsTransport";
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
            iceTransport: RTCIceTransport = undefined,
            state: RTCDtlsTransportState = undefined,
            onstatechange: EventHandler = undefined,
            onerror: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCDtlsTransport, .{
        .deinit_fn = &deinit_wrapper,

        .get_iceTransport = &get_iceTransport,
        .get_onerror = &get_onerror,
        .get_onstatechange = &get_onstatechange,
        .get_state = &get_state,

        .set_onerror = &set_onerror,
        .set_onstatechange = &set_onstatechange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getRemoteCertificates = &call_getRemoteCertificates,
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
        RTCDtlsTransportImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RTCDtlsTransportImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_iceTransport(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_iceTransport) |cached| {
            return cached;
        }
        const value = RTCDtlsTransportImpl.get_iceTransport(state);
        state.cached_iceTransport = value;
        return value;
    }

    pub fn get_state(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDtlsTransportImpl.get_state(state);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDtlsTransportImpl.get_onstatechange(state);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCDtlsTransportImpl.set_onstatechange(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDtlsTransportImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCDtlsTransportImpl.set_onerror(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return RTCDtlsTransportImpl.call_dispatchEvent(state, event);
    }

    pub fn call_getRemoteCertificates(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDtlsTransportImpl.call_getRemoteCertificates(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCDtlsTransportImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCDtlsTransportImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCDtlsTransportImpl.call_removeEventListener(state, type_, callback, options);
    }

};
