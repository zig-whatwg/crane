//! Generated from: payment-handler.idl
//! Generated at: 2025-11-23T01:18:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PaymentManagerImpl = @import("impls").PaymentManager;
const PaymentDelegation = @import("enums").PaymentDelegation;
const DOMString = @import("typedefs").DOMString;

pub const PaymentManager = struct {
    pub const Meta = struct {
        pub const name = "PaymentManager";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "userHint", "get_userHint", "set_userHint" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "enableDelegations", "call_enableDelegations", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "enableDelegations",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "userHint", "get_userHint", "set_userHint" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            userHint: runtime.DOMString = undefined,
        },
    );

    const delegates = .{

        .get_userHint = &get_userHint,

        .set_userHint = &set_userHint,

        .call_enableDelegations = &call_enableDelegations,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PaymentManagerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaymentManagerImpl.deinit(instance);
    }

    pub fn get_userHint(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentManagerImpl.get_userHint(instance);
    }

    pub fn set_userHint(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try PaymentManagerImpl.set_userHint(instance, value);
    }

    pub fn call_enableDelegations(instance: *runtime.Instance, delegations: *const anyopaque) anyerror!*const anyopaque {
        
        return try PaymentManagerImpl.call_enableDelegations(instance, delegations);
    }

};
