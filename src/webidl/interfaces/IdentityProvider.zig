//! Generated from: fedcm.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IdentityProviderImpl = @import("impls").IdentityProvider;
const mixins = @import("mixins");
const IdentityResolveOptions = @import("dictionaries").IdentityResolveOptions;
const IdentityProviderConfig = @import("dictionaries").IdentityProviderConfig;

pub const IdentityProvider = struct {
    pub const Meta = struct {
        pub const name = "IdentityProvider";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "close", "call_static_close", 0 },
            .{ "resolve", "call_static_resolve", 1 },
            .{ "getUserInfo", "call_static_getUserInfo", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "close",
            "resolve",
            "getUserInfo",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*IdentityProviderImpl.InternalState = null,
        },
    );

    const delegates = .{
        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IdentityProviderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return IdentityProviderImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IdentityProviderImpl.deinit(instance);
    }

    pub fn call_static_getUserInfo(instance: *runtime.Instance, config: IdentityProviderConfig) anyerror!*const anyopaque {
        return try IdentityProviderImpl.call_static_getUserInfo(instance, config);
    }

    pub fn call_static_resolve(instance: *runtime.Instance, token: runtime.JSValue, options: webidl.Opt(IdentityResolveOptions)) anyerror!*const anyopaque {
        return try IdentityProviderImpl.call_static_resolve(instance, token, options);
    }

    pub fn call_static_close(instance: *runtime.Instance) anyerror!void {
        return try IdentityProviderImpl.call_static_close(instance);
    }
};
