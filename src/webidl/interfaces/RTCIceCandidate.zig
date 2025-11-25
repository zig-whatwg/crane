//! Generated from: webrtc.idl
//! Generated at: 2025-11-25T14:21:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCIceCandidateImpl = @import("impls").RTCIceCandidate;
const RTCLocalIceCandidateInit = @import("dictionaries").RTCLocalIceCandidateInit;
const RTCIceComponent = @import("enums").RTCIceComponent;
const RTCIceProtocol = @import("enums").RTCIceProtocol;
const RTCIceTcpCandidateType = @import("enums").RTCIceTcpCandidateType;
const RTCIceCandidateType = @import("enums").RTCIceCandidateType;
const RTCIceServerTransportProtocol = @import("enums").RTCIceServerTransportProtocol;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;
const RTCIceCandidateInit = @import("dictionaries").RTCIceCandidateInit;

pub const RTCIceCandidate = struct {
    pub const Meta = struct {
        pub const name = "RTCIceCandidate";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "candidate", "get_candidate", null },
            .{ "sdpMid", "get_sdpMid", null },
            .{ "sdpMLineIndex", "get_sdpMLineIndex", null },
            .{ "foundation", "get_foundation", null },
            .{ "component", "get_component", null },
            .{ "priority", "get_priority", null },
            .{ "address", "get_address", null },
            .{ "protocol", "get_protocol", null },
            .{ "port", "get_port", null },
            .{ "type", "get_type", null },
            .{ "tcpType", "get_tcpType", null },
            .{ "relatedAddress", "get_relatedAddress", null },
            .{ "relatedPort", "get_relatedPort", null },
            .{ "usernameFragment", "get_usernameFragment", null },
            .{ "relayProtocol", "get_relayProtocol", null },
            .{ "url", "get_url", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "candidate", "get_candidate", null },
            .{ "sdpMid", "get_sdpMid", null },
            .{ "sdpMLineIndex", "get_sdpMLineIndex", null },
            .{ "foundation", "get_foundation", null },
            .{ "component", "get_component", null },
            .{ "priority", "get_priority", null },
            .{ "address", "get_address", null },
            .{ "protocol", "get_protocol", null },
            .{ "port", "get_port", null },
            .{ "type", "get_type", null },
            .{ "tcpType", "get_tcpType", null },
            .{ "relatedAddress", "get_relatedAddress", null },
            .{ "relatedPort", "get_relatedPort", null },
            .{ "usernameFragment", "get_usernameFragment", null },
            .{ "relayProtocol", "get_relayProtocol", null },
            .{ "url", "get_url", null },
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
            candidate: runtime.DOMString = undefined,
            sdpMid: ?runtime.DOMString = null,
            sdpMLineIndex: ?u16 = null,
            foundation: ?runtime.DOMString = null,
            component: ?RTCIceComponent = null,
            priority: ?u32 = null,
            address: ?runtime.DOMString = null,
            protocol: ?RTCIceProtocol = null,
            port: ?u16 = null,
            @"type": ?RTCIceCandidateType = null,
            tcpType: ?RTCIceTcpCandidateType = null,
            relatedAddress: ?runtime.DOMString = null,
            relatedPort: ?u16 = null,
            usernameFragment: ?runtime.DOMString = null,
            relayProtocol: ?RTCIceServerTransportProtocol = null,
            url: ?runtime.USVString = null,
            _internal: ?*RTCIceCandidateImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCIceCandidateImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCIceCandidateImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, candidateInitDict: RTCLocalIceCandidateInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RTCIceCandidateImpl.call_constructor(allocator, ctx, candidateInitDict);
    }

    pub fn get_candidate(instance: *runtime.Instance) anyerror!DOMString {
        return try RTCIceCandidateImpl.get_candidate(instance);
    }

    pub fn get_sdpMid(instance: *runtime.Instance) anyerror!?DOMString {
        return try RTCIceCandidateImpl.get_sdpMid(instance);
    }

    pub fn get_sdpMLineIndex(instance: *runtime.Instance) anyerror!?u16 {
        return try RTCIceCandidateImpl.get_sdpMLineIndex(instance);
    }

    pub fn get_foundation(instance: *runtime.Instance) anyerror!?DOMString {
        return try RTCIceCandidateImpl.get_foundation(instance);
    }

    pub fn get_component(instance: *runtime.Instance) anyerror!?RTCIceComponent {
        return try RTCIceCandidateImpl.get_component(instance);
    }

    pub fn get_priority(instance: *runtime.Instance) anyerror!?u32 {
        return try RTCIceCandidateImpl.get_priority(instance);
    }

    pub fn get_address(instance: *runtime.Instance) anyerror!?DOMString {
        return try RTCIceCandidateImpl.get_address(instance);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!?RTCIceProtocol {
        return try RTCIceCandidateImpl.get_protocol(instance);
    }

    pub fn get_port(instance: *runtime.Instance) anyerror!?u16 {
        return try RTCIceCandidateImpl.get_port(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!?RTCIceCandidateType {
        return try RTCIceCandidateImpl.get_type(instance);
    }

    pub fn get_tcpType(instance: *runtime.Instance) anyerror!?RTCIceTcpCandidateType {
        return try RTCIceCandidateImpl.get_tcpType(instance);
    }

    pub fn get_relatedAddress(instance: *runtime.Instance) anyerror!?DOMString {
        return try RTCIceCandidateImpl.get_relatedAddress(instance);
    }

    pub fn get_relatedPort(instance: *runtime.Instance) anyerror!?u16 {
        return try RTCIceCandidateImpl.get_relatedPort(instance);
    }

    pub fn get_usernameFragment(instance: *runtime.Instance) anyerror!?DOMString {
        return try RTCIceCandidateImpl.get_usernameFragment(instance);
    }

    pub fn get_relayProtocol(instance: *runtime.Instance) anyerror!?RTCIceServerTransportProtocol {
        return try RTCIceCandidateImpl.get_relayProtocol(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!?runtime.USVString {
        return try RTCIceCandidateImpl.get_url(instance);
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyerror!RTCIceCandidateInit {
        return try RTCIceCandidateImpl.call_toJSON(instance);
    }

};
