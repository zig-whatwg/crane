//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorConcurrentHardwareImpl = @import("../impls/NavigatorConcurrentHardware.zig");

pub const NavigatorConcurrentHardware = struct {
    pub const Meta = struct {
        pub const name = "NavigatorConcurrentHardware";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            hardwareConcurrency: u64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigatorConcurrentHardware, .{
        .deinit_fn = &deinit_wrapper,

        .get_hardwareConcurrency = &get_hardwareConcurrency,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        NavigatorConcurrentHardwareImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NavigatorConcurrentHardwareImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_hardwareConcurrency(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return NavigatorConcurrentHardwareImpl.get_hardwareConcurrency(state);
    }

};
