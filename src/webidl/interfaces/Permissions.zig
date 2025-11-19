//! Generated from: permissions.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PermissionsImpl = @import("impls").Permissions;
const PermissionStatus = @import("interfaces").PermissionStatus;

pub const Permissions = struct {
    pub const Meta = struct {
        pub const name = "Permissions";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Permissions, .{
        .deinit_fn = &deinit_wrapper,

        .call_query = &call_query,
        .call_request = &call_request,
        .call_revoke = &call_revoke,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return PermissionsImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PermissionsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_revoke(instance: *runtime.Instance, permissionDesc: anyopaque) anyerror!anyopaque {
        
        return try PermissionsImpl.call_revoke(instance, permissionDesc);
    }

    pub fn call_request(instance: *runtime.Instance, permissionDesc: anyopaque) anyerror!anyopaque {
        
        return try PermissionsImpl.call_request(instance, permissionDesc);
    }

    pub fn call_query(instance: *runtime.Instance, permissionDesc: anyopaque) anyerror!anyopaque {
        
        return try PermissionsImpl.call_query(instance, permissionDesc);
    }

};
