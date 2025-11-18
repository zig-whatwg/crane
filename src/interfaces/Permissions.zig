//! Generated from: permissions.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PermissionsImpl = @import("../impls/Permissions.zig");

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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        PermissionsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PermissionsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_revoke(instance: *runtime.Instance, permissionDesc: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PermissionsImpl.call_revoke(state, permissionDesc);
    }

    pub fn call_request(instance: *runtime.Instance, permissionDesc: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PermissionsImpl.call_request(state, permissionDesc);
    }

    pub fn call_query(instance: *runtime.Instance, permissionDesc: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PermissionsImpl.call_query(state, permissionDesc);
    }

};
