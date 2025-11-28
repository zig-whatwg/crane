//! Generated from: badging.idl
//! Generated at: 2025-11-28T18:02:25Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorBadgeImpl = @import("impls").NavigatorBadge;

pub const NavigatorBadge = struct {
    pub const Meta = struct {
        pub const name = "NavigatorBadge";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setAppBadge", "call_setAppBadge", 0 },
            .{ "clearAppBadge", "call_clearAppBadge", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setAppBadge",
            "clearAppBadge",
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
        struct {
            _internal: ?*NavigatorBadgeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_clearAppBadge = &call_clearAppBadge,
        .call_setAppBadge = &call_setAppBadge,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigatorBadgeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorBadgeImpl.deinit(instance);
    }

    pub fn call_setAppBadge(instance: *runtime.Instance, contents: u64) anyerror!*const anyopaque {
        // [EnforceRange] on contents
        if (!runtime.isInRange(u64, contents)) return error.TypeError;
        
        return try NavigatorBadgeImpl.call_setAppBadge(instance, contents);
    }

    pub fn call_clearAppBadge(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigatorBadgeImpl.call_clearAppBadge(instance);
    }

};
