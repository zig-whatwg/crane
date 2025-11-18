//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const UserActivationImpl = @import("../impls/UserActivation.zig");

pub const UserActivation = struct {
    pub const Meta = struct {
        pub const name = "UserActivation";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            hasBeenActive: bool = undefined,
            isActive: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(UserActivation, .{
        .deinit_fn = &deinit_wrapper,

        .get_hasBeenActive = &get_hasBeenActive,
        .get_isActive = &get_isActive,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        UserActivationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        UserActivationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_hasBeenActive(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return UserActivationImpl.get_hasBeenActive(state);
    }

    pub fn get_isActive(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return UserActivationImpl.get_isActive(state);
    }

};
