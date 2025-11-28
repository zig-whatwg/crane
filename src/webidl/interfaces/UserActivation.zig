//! Generated from: html.idl
//! Generated at: 2025-11-28T19:51:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const UserActivationImpl = @import("impls").UserActivation;
const mixins = @import("mixins");

pub const UserActivation = struct {
    pub const Meta = struct {
        pub const name = "UserActivation";
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
            .{ "hasBeenActive", "get_hasBeenActive", null },
            .{ "isActive", "get_isActive", null },
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
            .{ "hasBeenActive", "get_hasBeenActive", null },
            .{ "isActive", "get_isActive", null },
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
            hasBeenActive: bool = undefined,
            isActive: bool = undefined,
            _internal: ?*UserActivationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_hasBeenActive = &get_hasBeenActive,
        .get_isActive = &get_isActive,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return UserActivationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        UserActivationImpl.deinit(instance);
    }

    pub fn get_hasBeenActive(instance: *runtime.Instance) anyerror!bool {
        return try UserActivationImpl.get_hasBeenActive(instance);
    }

    pub fn get_isActive(instance: *runtime.Instance) anyerror!bool {
        return try UserActivationImpl.get_isActive(instance);
    }

};
