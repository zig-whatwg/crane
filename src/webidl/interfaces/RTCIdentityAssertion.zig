//! Generated from: webrtc-identity.idl
//! Generated at: 2025-11-28T18:02:25Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCIdentityAssertionImpl = @import("impls").RTCIdentityAssertion;
const DOMString = @import("typedefs").DOMString;

pub const RTCIdentityAssertion = struct {
    pub const Meta = struct {
        pub const name = "RTCIdentityAssertion";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "idp", "get_idp", "set_idp" },
            .{ "name", "get_name", "set_name" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "idp", "get_idp", "set_idp" },
            .{ "name", "get_name", "set_name" },
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
            idp: runtime.DOMString = undefined,
            name: runtime.DOMString = undefined,
            _internal: ?*RTCIdentityAssertionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_idp = &get_idp,
        .get_name = &get_name,

        .set_idp = &set_idp,
        .set_name = &set_name,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCIdentityAssertionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCIdentityAssertionImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, idp: DOMString, name: DOMString) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RTCIdentityAssertionImpl.call_constructor(allocator, ctx, idp, name);
    }

    pub fn get_idp(instance: *runtime.Instance) anyerror!DOMString {
        return try RTCIdentityAssertionImpl.get_idp(instance);
    }

    pub fn set_idp(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try RTCIdentityAssertionImpl.set_idp(instance, value);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try RTCIdentityAssertionImpl.get_name(instance);
    }

    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try RTCIdentityAssertionImpl.set_name(instance, value);
    }

};
