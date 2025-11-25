//! Generated from: webrtc.idl
//! Generated at: 2025-11-25T14:21:40Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCPeerConnectionIceErrorEventImpl = @import("impls").RTCPeerConnectionIceErrorEvent;
const Event = @import("interfaces").Event;
const RTCPeerConnectionIceErrorEventInit = @import("dictionaries").RTCPeerConnectionIceErrorEventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const RTCPeerConnectionIceErrorEvent = struct {
    pub const Meta = struct {
        pub const name = "RTCPeerConnectionIceErrorEvent";
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
            .{ "address", "get_address", null },
            .{ "port", "get_port", null },
            .{ "url", "get_url", null },
            .{ "errorCode", "get_errorCode", null },
            .{ "errorText", "get_errorText", null },
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
            .{ "address", "get_address", null },
            .{ "port", "get_port", null },
            .{ "url", "get_url", null },
            .{ "errorCode", "get_errorCode", null },
            .{ "errorText", "get_errorText", null },
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
            address: ?runtime.DOMString = null,
            port: ?u16 = null,
            url: runtime.USVString = undefined,
            errorCode: u16 = undefined,
            errorText: runtime.USVString = undefined,
            _internal: ?*RTCPeerConnectionIceErrorEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_address = &get_address,
        .get_errorCode = &get_errorCode,
        .get_errorText = &get_errorText,
        .get_port = &get_port,
        .get_url = &get_url,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCPeerConnectionIceErrorEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCPeerConnectionIceErrorEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: RTCPeerConnectionIceErrorEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RTCPeerConnectionIceErrorEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_address(instance: *runtime.Instance) anyerror!?DOMString {
        return try RTCPeerConnectionIceErrorEventImpl.get_address(instance);
    }

    pub fn get_port(instance: *runtime.Instance) anyerror!?u16 {
        return try RTCPeerConnectionIceErrorEventImpl.get_port(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RTCPeerConnectionIceErrorEventImpl.get_url(instance);
    }

    pub fn get_errorCode(instance: *runtime.Instance) anyerror!u16 {
        return try RTCPeerConnectionIceErrorEventImpl.get_errorCode(instance);
    }

    pub fn get_errorText(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RTCPeerConnectionIceErrorEventImpl.get_errorText(instance);
    }

};
