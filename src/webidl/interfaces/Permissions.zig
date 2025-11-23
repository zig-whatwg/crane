//! Generated from: permissions.idl
//! Generated at: 2025-11-23T14:26:30Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PermissionsImpl = @import("impls").Permissions;
const PermissionStatus = @import("interfaces").PermissionStatus;

pub const Permissions = struct {
    pub const Meta = struct {
        pub const name = "Permissions";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
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
            .{ "query", "call_query", 1 },
            .{ "request", "call_request", 1 },
            .{ "revoke", "call_revoke", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "query",
            "request",
            "revoke",
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

        .call_query = &call_query,
        .call_request = &call_request,
        .call_revoke = &call_revoke,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PermissionsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PermissionsImpl.deinit(instance);
    }

    pub fn call_revoke(instance: *runtime.Instance, permissionDesc: *const anyopaque) anyerror!*const anyopaque {
        
        return try PermissionsImpl.call_revoke(instance, permissionDesc);
    }

    pub fn call_request(instance: *runtime.Instance, permissionDesc: *const anyopaque) anyerror!*const anyopaque {
        
        return try PermissionsImpl.call_request(instance, permissionDesc);
    }

    pub fn call_query(instance: *runtime.Instance, permissionDesc: *const anyopaque) anyerror!*const anyopaque {
        
        return try PermissionsImpl.call_query(instance, permissionDesc);
    }

};
