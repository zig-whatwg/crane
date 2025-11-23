//! Generated from: webrtc.idl
//! Generated at: 2025-11-23T16:59:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCIceTransportImpl = @import("impls").RTCIceTransport;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const RTCIceGatherOptions = @import("dictionaries").RTCIceGatherOptions;
const RTCIceRole = @import("enums").RTCIceRole;
const RTCIceCandidatePair = @import("interfaces").RTCIceCandidatePair;
const RTCIceTransportState = @import("enums").RTCIceTransportState;
const RTCIceCandidateInit = @import("dictionaries").RTCIceCandidateInit;
const RTCIceGathererState = @import("enums").RTCIceGathererState;
const RTCIceComponent = @import("enums").RTCIceComponent;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const RTCIceParameters = @import("dictionaries").RTCIceParameters;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const RTCIceCandidate = @import("interfaces").RTCIceCandidate;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const RTCIceTransport = struct {
    pub const Meta = struct {
        pub const name = "RTCIceTransport";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "role", "get_role", null },
            .{ "component", "get_component", null },
            .{ "state", "get_state", null },
            .{ "gatheringState", "get_gatheringState", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
            .{ "ongatheringstatechange", "get_ongatheringstatechange", "set_ongatheringstatechange" },
            .{ "onselectedcandidatepairchange", "get_onselectedcandidatepairchange", "set_onselectedcandidatepairchange" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onicecandidate", "get_onicecandidate", "set_onicecandidate" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getLocalCandidates", "call_getLocalCandidates", 0 },
            .{ "getRemoteCandidates", "call_getRemoteCandidates", 0 },
            .{ "getSelectedCandidatePair", "call_getSelectedCandidatePair", 0 },
            .{ "getLocalParameters", "call_getLocalParameters", 0 },
            .{ "getRemoteParameters", "call_getRemoteParameters", 0 },
            .{ "gather", "call_gather", 0 },
            .{ "start", "call_start", 0 },
            .{ "stop", "call_stop", 0 },
            .{ "addRemoteCandidate", "call_addRemoteCandidate", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getLocalCandidates",
            "getRemoteCandidates",
            "getSelectedCandidatePair",
            "getLocalParameters",
            "getRemoteParameters",
            "gather",
            "start",
            "stop",
            "addRemoteCandidate",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "role", "get_role", null },
            .{ "component", "get_component", null },
            .{ "state", "get_state", null },
            .{ "gatheringState", "get_gatheringState", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
            .{ "ongatheringstatechange", "get_ongatheringstatechange", "set_ongatheringstatechange" },
            .{ "onselectedcandidatepairchange", "get_onselectedcandidatepairchange", "set_onselectedcandidatepairchange" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onicecandidate", "get_onicecandidate", "set_onicecandidate" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
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
            _internal: ?*RTCIceTransportImpl.InternalState = null,
        },
    );

    const delegates = .{

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

        .call_addRemoteCandidate = &call_addRemoteCandidate,
        .call_gather = &call_gather,
        .call_getLocalCandidates = &call_getLocalCandidates,
        .call_getLocalParameters = &call_getLocalParameters,
        .call_getRemoteCandidates = &call_getRemoteCandidates,
        .call_getRemoteParameters = &call_getRemoteParameters,
        .call_getSelectedCandidatePair = &call_getSelectedCandidatePair,
        .call_start = &call_start,
        .call_stop = &call_stop,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCIceTransportImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCIceTransportImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RTCIceTransportImpl.call_constructor(allocator, ctx);
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

    pub fn call_gather(instance: *runtime.Instance, options: RTCIceGatherOptions) anyerror!void {
        
        return try RTCIceTransportImpl.call_gather(instance, options);
    }

    pub fn call_addRemoteCandidate(instance: *runtime.Instance, remoteCandidate: RTCIceCandidateInit) anyerror!void {
        
        return try RTCIceTransportImpl.call_addRemoteCandidate(instance, remoteCandidate);
    }

    pub fn call_getRemoteParameters(instance: *runtime.Instance) anyerror!RTCIceParameters {
        return try RTCIceTransportImpl.call_getRemoteParameters(instance);
    }

    pub fn call_getLocalParameters(instance: *runtime.Instance) anyerror!RTCIceParameters {
        return try RTCIceTransportImpl.call_getLocalParameters(instance);
    }

    pub fn call_getSelectedCandidatePair(instance: *runtime.Instance) anyerror!RTCIceCandidatePair {
        return try RTCIceTransportImpl.call_getSelectedCandidatePair(instance);
    }

    pub fn call_getLocalCandidates(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RTCIceTransportImpl.call_getLocalCandidates(instance);
    }

    pub fn call_getRemoteCandidates(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RTCIceTransportImpl.call_getRemoteCandidates(instance);
    }

    pub fn call_start(instance: *runtime.Instance, remoteParameters: RTCIceParameters, role: RTCIceRole) anyerror!void {
        
        return try RTCIceTransportImpl.call_start(instance, remoteParameters, role);
    }

};
