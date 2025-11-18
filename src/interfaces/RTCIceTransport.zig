//! Generated from: webrtc.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCIceTransportImpl = @import("../impls/RTCIceTransport.zig");
const EventTarget = @import("EventTarget.zig");

pub const RTCIceTransport = struct {
    pub const Meta = struct {
        pub const name = "RTCIceTransport";
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
            role: RTCIceRole = undefined,
            component: RTCIceComponent = undefined,
            state: RTCIceTransportState = undefined,
            gatheringState: RTCIceGathererState = undefined,
            onstatechange: EventHandler = undefined,
            ongatheringstatechange: EventHandler = undefined,
            onselectedcandidatepairchange: EventHandler = undefined,
            onerror: EventHandler = undefined,
            onicecandidate: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCIceTransport, .{
        .deinit_fn = &deinit_wrapper,

        .get_component = &get_component,
        .get_gatheringState = &get_gatheringState,
        .get_onerror = &get_onerror,
        .get_ongatheringstatechange = &get_ongatheringstatechange,
        .get_onicecandidate = &get_onicecandidate,
        .get_onselectedcandidatepairchange = &get_onselectedcandidatepairchange,
        .get_onstatechange = &get_onstatechange,
        .get_role = &get_role,
        .get_state = &get_state,

        .set_onerror = &set_onerror,
        .set_ongatheringstatechange = &set_ongatheringstatechange,
        .set_onicecandidate = &set_onicecandidate,
        .set_onselectedcandidatepairchange = &set_onselectedcandidatepairchange,
        .set_onstatechange = &set_onstatechange,

        .call_addEventListener = &call_addEventListener,
        .call_addRemoteCandidate = &call_addRemoteCandidate,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_gather = &call_gather,
        .call_getLocalCandidates = &call_getLocalCandidates,
        .call_getLocalParameters = &call_getLocalParameters,
        .call_getRemoteCandidates = &call_getRemoteCandidates,
        .call_getRemoteParameters = &call_getRemoteParameters,
        .call_getSelectedCandidatePair = &call_getSelectedCandidatePair,
        .call_removeEventListener = &call_removeEventListener,
        .call_start = &call_start,
        .call_stop = &call_stop,
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
        RTCIceTransportImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RTCIceTransportImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try RTCIceTransportImpl.constructor(state);
        
        return instance;
    }

    pub fn get_role(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceTransportImpl.get_role(state);
    }

    pub fn get_component(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceTransportImpl.get_component(state);
    }

    pub fn get_state(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceTransportImpl.get_state(state);
    }

    pub fn get_gatheringState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceTransportImpl.get_gatheringState(state);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceTransportImpl.get_onstatechange(state);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCIceTransportImpl.set_onstatechange(state, value);
    }

    pub fn get_ongatheringstatechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceTransportImpl.get_ongatheringstatechange(state);
    }

    pub fn set_ongatheringstatechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCIceTransportImpl.set_ongatheringstatechange(state, value);
    }

    pub fn get_onselectedcandidatepairchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceTransportImpl.get_onselectedcandidatepairchange(state);
    }

    pub fn set_onselectedcandidatepairchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCIceTransportImpl.set_onselectedcandidatepairchange(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceTransportImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCIceTransportImpl.set_onerror(state, value);
    }

    pub fn get_onicecandidate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceTransportImpl.get_onicecandidate(state);
    }

    pub fn set_onicecandidate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCIceTransportImpl.set_onicecandidate(state, value);
    }

    pub fn call_stop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceTransportImpl.call_stop(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCIceTransportImpl.call_when(state, type_, options);
    }

    pub fn call_gather(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCIceTransportImpl.call_gather(state, options);
    }

    pub fn call_getLocalParameters(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceTransportImpl.call_getLocalParameters(state);
    }

    pub fn call_getSelectedCandidatePair(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceTransportImpl.call_getSelectedCandidatePair(state);
    }

    pub fn call_getRemoteCandidates(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceTransportImpl.call_getRemoteCandidates(state);
    }

    pub fn call_start(instance: *runtime.Instance, remoteParameters: anyopaque, role: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCIceTransportImpl.call_start(state, remoteParameters, role);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCIceTransportImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCIceTransportImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_addRemoteCandidate(instance: *runtime.Instance, remoteCandidate: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCIceTransportImpl.call_addRemoteCandidate(state, remoteCandidate);
    }

    pub fn call_getRemoteParameters(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceTransportImpl.call_getRemoteParameters(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return RTCIceTransportImpl.call_dispatchEvent(state, event);
    }

    pub fn call_getLocalCandidates(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceTransportImpl.call_getLocalCandidates(state);
    }

};
