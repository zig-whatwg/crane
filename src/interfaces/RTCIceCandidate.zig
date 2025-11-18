//! Generated from: webrtc.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCIceCandidateImpl = @import("../impls/RTCIceCandidate.zig");

pub const RTCIceCandidate = struct {
    pub const Meta = struct {
        pub const name = "RTCIceCandidate";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            candidate: runtime.DOMString = undefined,
            sdpMid: ?runtime.DOMString = null,
            sdpMLineIndex: ?u16 = null,
            foundation: ?runtime.DOMString = null,
            component: ?RTCIceComponent = null,
            priority: ?u32 = null,
            address: ?runtime.DOMString = null,
            protocol: ?RTCIceProtocol = null,
            port: ?u16 = null,
            type: ?RTCIceCandidateType = null,
            tcpType: ?RTCIceTcpCandidateType = null,
            relatedAddress: ?runtime.DOMString = null,
            relatedPort: ?u16 = null,
            usernameFragment: ?runtime.DOMString = null,
            relayProtocol: ?RTCIceServerTransportProtocol = null,
            url: ?runtime.USVString = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCIceCandidate, .{
        .deinit_fn = &deinit_wrapper,

        .get_address = &get_address,
        .get_candidate = &get_candidate,
        .get_component = &get_component,
        .get_foundation = &get_foundation,
        .get_port = &get_port,
        .get_priority = &get_priority,
        .get_protocol = &get_protocol,
        .get_relatedAddress = &get_relatedAddress,
        .get_relatedPort = &get_relatedPort,
        .get_relayProtocol = &get_relayProtocol,
        .get_sdpMLineIndex = &get_sdpMLineIndex,
        .get_sdpMid = &get_sdpMid,
        .get_tcpType = &get_tcpType,
        .get_type = &get_type,
        .get_url = &get_url,
        .get_usernameFragment = &get_usernameFragment,

        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        RTCIceCandidateImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RTCIceCandidateImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, candidateInitDict: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try RTCIceCandidateImpl.constructor(state, candidateInitDict);
        
        return instance;
    }

    pub fn get_candidate(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.get_candidate(state);
    }

    pub fn get_sdpMid(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.get_sdpMid(state);
    }

    pub fn get_sdpMLineIndex(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.get_sdpMLineIndex(state);
    }

    pub fn get_foundation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.get_foundation(state);
    }

    pub fn get_component(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.get_component(state);
    }

    pub fn get_priority(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.get_priority(state);
    }

    pub fn get_address(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.get_address(state);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.get_protocol(state);
    }

    pub fn get_port(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.get_port(state);
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.get_type(state);
    }

    pub fn get_tcpType(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.get_tcpType(state);
    }

    pub fn get_relatedAddress(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.get_relatedAddress(state);
    }

    pub fn get_relatedPort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.get_relatedPort(state);
    }

    pub fn get_usernameFragment(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.get_usernameFragment(state);
    }

    pub fn get_relayProtocol(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.get_relayProtocol(state);
    }

    pub fn get_url(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.get_url(state);
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCIceCandidateImpl.call_toJSON(state);
    }

};
