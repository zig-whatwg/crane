//! Generated from: webrtc.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCIceTransportImpl = @import("impls").RTCIceTransport;
const EventTarget = @import("interfaces").EventTarget;
const RTCIceComponent = @import("enums").RTCIceComponent;
const RTCIceCandidateInit = @import("dictionaries").RTCIceCandidateInit;
const RTCIceParameters = @import("dictionaries").RTCIceParameters;
const RTCIceGatherOptions = @import("dictionaries").RTCIceGatherOptions;
const RTCIceRole = @import("enums").RTCIceRole;
const RTCIceCandidatePair = @import("interfaces").RTCIceCandidatePair;
const RTCIceTransportState = @import("enums").RTCIceTransportState;
const EventHandler = @import("typedefs").EventHandler;
const RTCIceGathererState = @import("enums").RTCIceGathererState;

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
        
        // Initialize the instance (Impl receives full instance)
        RTCIceTransportImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCIceTransportImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try RTCIceTransportImpl.constructor(instance);
        
        return instance;
    }

    pub fn get_role(instance: *runtime.Instance) anyerror!RTCIceRole {
        return try RTCIceTransportImpl.get_role(instance);
    }

    pub fn get_component(instance: *runtime.Instance) anyerror!RTCIceComponent {
        return try RTCIceTransportImpl.get_component(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!RTCIceTransportState {
        return try RTCIceTransportImpl.get_state(instance);
    }

    pub fn get_gatheringState(instance: *runtime.Instance) anyerror!RTCIceGathererState {
        return try RTCIceTransportImpl.get_gatheringState(instance);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCIceTransportImpl.get_onstatechange(instance);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCIceTransportImpl.set_onstatechange(instance, value);
    }

    pub fn get_ongatheringstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCIceTransportImpl.get_ongatheringstatechange(instance);
    }

    pub fn set_ongatheringstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCIceTransportImpl.set_ongatheringstatechange(instance, value);
    }

    pub fn get_onselectedcandidatepairchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCIceTransportImpl.get_onselectedcandidatepairchange(instance);
    }

    pub fn set_onselectedcandidatepairchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCIceTransportImpl.set_onselectedcandidatepairchange(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCIceTransportImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCIceTransportImpl.set_onerror(instance, value);
    }

    pub fn get_onicecandidate(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCIceTransportImpl.get_onicecandidate(instance);
    }

    pub fn set_onicecandidate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCIceTransportImpl.set_onicecandidate(instance, value);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try RTCIceTransportImpl.call_stop(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try RTCIceTransportImpl.call_when(instance, type_, options);
    }

    pub fn call_gather(instance: *runtime.Instance, options: RTCIceGatherOptions) anyerror!void {
        
        return try RTCIceTransportImpl.call_gather(instance, options);
    }

    pub fn call_getLocalParameters(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceTransportImpl.call_getLocalParameters(instance);
    }

    pub fn call_getSelectedCandidatePair(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceTransportImpl.call_getSelectedCandidatePair(instance);
    }

    pub fn call_getRemoteCandidates(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceTransportImpl.call_getRemoteCandidates(instance);
    }

    pub fn call_start(instance: *runtime.Instance, remoteParameters: RTCIceParameters, role: RTCIceRole) anyerror!void {
        
        return try RTCIceTransportImpl.call_start(instance, remoteParameters, role);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try RTCIceTransportImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try RTCIceTransportImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_addRemoteCandidate(instance: *runtime.Instance, remoteCandidate: RTCIceCandidateInit) anyerror!void {
        
        return try RTCIceTransportImpl.call_addRemoteCandidate(instance, remoteCandidate);
    }

    pub fn call_getRemoteParameters(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceTransportImpl.call_getRemoteParameters(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try RTCIceTransportImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_getLocalCandidates(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceTransportImpl.call_getLocalCandidates(instance);
    }

};
