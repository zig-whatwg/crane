//! Generated from: service-workers.idl
//! Generated at: 2025-11-23T16:59:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigationPreloadManagerImpl = @import("impls").NavigationPreloadManager;
const ByteString = @import("interfaces").ByteString;
const NavigationPreloadState = @import("dictionaries").NavigationPreloadState;

pub const NavigationPreloadManager = struct {
    pub const Meta = struct {
        pub const name = "NavigationPreloadManager";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "enable", "call_enable", 0 },
            .{ "disable", "call_disable", 0 },
            .{ "setHeaderValue", "call_setHeaderValue", 1 },
            .{ "getState", "call_getState", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "enable",
            "disable",
            "setHeaderValue",
            "getState",
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

        .call_disable = &call_disable,
        .call_enable = &call_enable,
        .call_getState = &call_getState,
        .call_setHeaderValue = &call_setHeaderValue,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigationPreloadManagerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigationPreloadManagerImpl.deinit(instance);
    }

    pub fn call_setHeaderValue(instance: *runtime.Instance, value: runtime.ByteString) anyerror!*const anyopaque {
        
        return try NavigationPreloadManagerImpl.call_setHeaderValue(instance, value);
    }

    pub fn call_disable(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigationPreloadManagerImpl.call_disable(instance);
    }

    pub fn call_getState(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigationPreloadManagerImpl.call_getState(instance);
    }

    pub fn call_enable(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigationPreloadManagerImpl.call_enable(instance);
    }

};
