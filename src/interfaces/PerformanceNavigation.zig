//! Generated from: navigation-timing.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceNavigationImpl = @import("../impls/PerformanceNavigation.zig");

pub const PerformanceNavigation = struct {
    pub const Meta = struct {
        pub const name = "PerformanceNavigation";
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
            type: u16 = undefined,
            redirectCount: u16 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
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

    pub const vtable = runtime.buildVTable(PerformanceNavigation, .{
        .deinit_fn = &deinit_wrapper,

        .get_TYPE_BACK_FORWARD = &get_TYPE_BACK_FORWARD,
        .get_TYPE_NAVIGATE = &get_TYPE_NAVIGATE,
        .get_TYPE_RELOAD = &get_TYPE_RELOAD,
        .get_TYPE_RESERVED = &get_TYPE_RESERVED,
        .get_redirectCount = &get_redirectCount,
        .get_type = &get_type,

        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        PerformanceNavigationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PerformanceNavigationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return PerformanceNavigationImpl.get_type(state);
    }

    pub fn get_redirectCount(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return PerformanceNavigationImpl.get_redirectCount(state);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationImpl.call_toJSON(state);
    }

};
