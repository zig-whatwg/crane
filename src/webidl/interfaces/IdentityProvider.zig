//! Generated from: fedcm.idl
//! Generated at: 2025-11-23T01:18:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IdentityProviderImpl = @import("impls").IdentityProvider;
const IdentityResolveOptions = @import("dictionaries").IdentityResolveOptions;
const IdentityProviderConfig = @import("dictionaries").IdentityProviderConfig;

pub const IdentityProvider = struct {
    pub const Meta = struct {
        pub const name = "IdentityProvider";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "close", "call_close", 0 },
            .{ "resolve", "call_resolve", 1 },
            .{ "getUserInfo", "call_getUserInfo", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "close",
            "resolve",
            "getUserInfo",
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

        .call_close = &call_close,
        .call_getUserInfo = &call_getUserInfo,
        .call_resolve = &call_resolve,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IdentityProviderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IdentityProviderImpl.deinit(instance);
    }

    pub fn call_resolve(instance: *runtime.Instance, token: *const anyopaque, options: IdentityResolveOptions) anyerror!*const anyopaque {
        
        return try IdentityProviderImpl.call_resolve(instance, token, options);
    }

    pub fn call_getUserInfo(instance: *runtime.Instance, config: IdentityProviderConfig) anyerror!*const anyopaque {
        
        return try IdentityProviderImpl.call_getUserInfo(instance, config);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try IdentityProviderImpl.call_close(instance);
    }

};
