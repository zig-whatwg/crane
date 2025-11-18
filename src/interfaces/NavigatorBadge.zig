//! Generated from: badging.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorBadgeImpl = @import("../impls/NavigatorBadge.zig");

pub const NavigatorBadge = struct {
    pub const Meta = struct {
        pub const name = "NavigatorBadge";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigatorBadge, .{
        .deinit_fn = &deinit_wrapper,

        .call_clearAppBadge = &call_clearAppBadge,
        .call_setAppBadge = &call_setAppBadge,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        NavigatorBadgeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NavigatorBadgeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_setAppBadge(instance: *runtime.Instance, contents: u64) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on contents
        if (contents > std.math.maxInt(u53)) return error.TypeError;
        
        return NavigatorBadgeImpl.call_setAppBadge(state, contents);
    }

    pub fn call_clearAppBadge(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorBadgeImpl.call_clearAppBadge(state);
    }

};
