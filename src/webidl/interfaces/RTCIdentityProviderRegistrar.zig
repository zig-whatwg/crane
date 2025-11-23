//! Generated from: webrtc-identity.idl
//! Generated at: 2025-11-23T01:18:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCIdentityProviderRegistrarImpl = @import("impls").RTCIdentityProviderRegistrar;
const RTCIdentityProvider = @import("dictionaries").RTCIdentityProvider;

pub const RTCIdentityProviderRegistrar = struct {
    pub const Meta = struct {
        pub const name = "RTCIdentityProviderRegistrar";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "RTCIdentityProvider" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .RTCIdentityProvider = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "register", "call_register", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "register",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_register = &call_register,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCIdentityProviderRegistrarImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCIdentityProviderRegistrarImpl.deinit(instance);
    }

    pub fn call_register(instance: *runtime.Instance, idp: RTCIdentityProvider) anyerror!void {
        
        return try RTCIdentityProviderRegistrarImpl.call_register(instance, idp);
    }

};
