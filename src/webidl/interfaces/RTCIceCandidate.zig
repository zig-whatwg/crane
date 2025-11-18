//! Generated from: webrtc.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCIceCandidateImpl = @import("impls").RTCIceCandidate;
const RTCLocalIceCandidateInit = @import("dictionaries").RTCLocalIceCandidateInit;
const RTCIceComponent = @import("enums").RTCIceComponent;
const unsigned short = @import("interfaces").unsigned short;
const RTCIceProtocol = @import("enums").RTCIceProtocol;
const RTCIceTcpCandidateType = @import("enums").RTCIceTcpCandidateType;
const RTCIceCandidateType = @import("enums").RTCIceCandidateType;
const RTCIceServerTransportProtocol = @import("enums").RTCIceServerTransportProtocol;
const unsigned long = @import("interfaces").unsigned long;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;
const RTCIceCandidateInit = @import("dictionaries").RTCIceCandidateInit;

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
        
        // Initialize the instance (Impl receives full instance)
        RTCIceCandidateImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCIceCandidateImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, candidateInitDict: RTCLocalIceCandidateInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try RTCIceCandidateImpl.constructor(instance, candidateInitDict);
        
        return instance;
    }

    pub fn get_candidate(instance: *runtime.Instance) anyerror!DOMString {
        return try RTCIceCandidateImpl.get_candidate(instance);
    }

    pub fn get_sdpMid(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceCandidateImpl.get_sdpMid(instance);
    }

    pub fn get_sdpMLineIndex(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceCandidateImpl.get_sdpMLineIndex(instance);
    }

    pub fn get_foundation(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceCandidateImpl.get_foundation(instance);
    }

    pub fn get_component(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceCandidateImpl.get_component(instance);
    }

    pub fn get_priority(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceCandidateImpl.get_priority(instance);
    }

    pub fn get_address(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceCandidateImpl.get_address(instance);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceCandidateImpl.get_protocol(instance);
    }

    pub fn get_port(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceCandidateImpl.get_port(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceCandidateImpl.get_type(instance);
    }

    pub fn get_tcpType(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceCandidateImpl.get_tcpType(instance);
    }

    pub fn get_relatedAddress(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceCandidateImpl.get_relatedAddress(instance);
    }

    pub fn get_relatedPort(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceCandidateImpl.get_relatedPort(instance);
    }

    pub fn get_usernameFragment(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceCandidateImpl.get_usernameFragment(instance);
    }

    pub fn get_relayProtocol(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceCandidateImpl.get_relayProtocol(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCIceCandidateImpl.get_url(instance);
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyerror!RTCIceCandidateInit {
        return try RTCIceCandidateImpl.call_toJSON(instance);
    }

};
