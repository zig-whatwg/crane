//! Generated from: webrtc.idl
//! Generated at: 2025-11-25T14:21:40Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCPeerConnectionIceEventImpl = @import("impls").RTCPeerConnectionIceEvent;
const Event = @import("interfaces").Event;
const EventInit = @import("dictionaries").EventInit;
const EventTarget = @import("interfaces").EventTarget;
const RTCPeerConnectionIceEventInit = @import("dictionaries").RTCPeerConnectionIceEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const RTCIceCandidate = @import("interfaces").RTCIceCandidate;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const RTCPeerConnectionIceEvent = struct {
    pub const Meta = struct {
        pub const name = "RTCPeerConnectionIceEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "candidate", "get_candidate", null },
            .{ "url", "get_url", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "candidate", "get_candidate", null },
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
            candidate: ?*runtime.Instance = null,
            url: ?runtime.USVString = null,
            _internal: ?*RTCPeerConnectionIceEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_candidate = &get_candidate,
        .get_url = &get_url,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCPeerConnectionIceEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCPeerConnectionIceEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: RTCPeerConnectionIceEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RTCPeerConnectionIceEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_candidate(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try RTCPeerConnectionIceEventImpl.get_candidate(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!?runtime.USVString {
        return try RTCPeerConnectionIceEventImpl.get_url(instance);
    }

};
