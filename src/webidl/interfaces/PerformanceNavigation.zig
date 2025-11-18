//! Generated from: navigation-timing.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceNavigationImpl = @import("impls").PerformanceNavigation;

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
        
        // Initialize the instance (Impl receives full instance)
        PerformanceNavigationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceNavigationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
        return try PerformanceNavigationImpl.get_type(instance);
    }

    pub fn get_redirectCount(instance: *runtime.Instance) anyerror!u16 {
        return try PerformanceNavigationImpl.get_redirectCount(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try PerformanceNavigationImpl.call_toJSON(instance);
    }

};
