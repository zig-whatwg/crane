//! Generated from: navigation-timing.idl
//! Generated at: 2025-11-25T13:07:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceNavigationImpl = @import("impls").PerformanceNavigation;

pub const PerformanceNavigation = struct {
    pub const Meta = struct {
        pub const name = "PerformanceNavigation";
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
            .{ "type", "get_type", null },
            .{ "redirectCount", "get_redirectCount", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "TYPE_NAVIGATE", "get_TYPE_NAVIGATE" },
            .{ "TYPE_RELOAD", "get_TYPE_RELOAD" },
            .{ "TYPE_BACK_FORWARD", "get_TYPE_BACK_FORWARD" },
            .{ "TYPE_RESERVED", "get_TYPE_RESERVED" },
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
            .{ "type", "get_type", null },
            .{ "redirectCount", "get_redirectCount", null },
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
            @"type": u16 = undefined,
            redirectCount: u16 = undefined,
            _internal: ?*PerformanceNavigationImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short TYPE_NAVIGATE = 0;
    pub fn get_TYPE_NAVIGATE() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short TYPE_RELOAD = 1;
    pub fn get_TYPE_RELOAD() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short TYPE_BACK_FORWARD = 2;
    pub fn get_TYPE_BACK_FORWARD() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short TYPE_RESERVED = 255;
    pub fn get_TYPE_RESERVED() u16 {
        return 255;
    }

    const delegates = .{

        .get_TYPE_BACK_FORWARD = &get_TYPE_BACK_FORWARD,
        .get_TYPE_NAVIGATE = &get_TYPE_NAVIGATE,
        .get_TYPE_RELOAD = &get_TYPE_RELOAD,
        .get_TYPE_RESERVED = &get_TYPE_RESERVED,
        .get_redirectCount = &get_redirectCount,
        .get_type = &get_type,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceNavigationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceNavigationImpl.deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
        return try PerformanceNavigationImpl.get_type(instance);
    }

    pub fn get_redirectCount(instance: *runtime.Instance) anyerror!u16 {
        return try PerformanceNavigationImpl.get_redirectCount(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PerformanceNavigationImpl.call_toJSON(instance);
    }

};
