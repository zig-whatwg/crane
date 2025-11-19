//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const UserActivationImpl = @import("impls").UserActivation;

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
        return UserActivationImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        UserActivationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_hasBeenActive(instance: *runtime.Instance) anyerror!bool {
        return try UserActivationImpl.get_hasBeenActive(instance);
    }

    pub fn get_isActive(instance: *runtime.Instance) anyerror!bool {
        return try UserActivationImpl.get_isActive(instance);
    }

};
