//! Generated from: streams.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CountQueuingStrategyImpl = @import("../impls/CountQueuingStrategy.zig");

pub const CountQueuingStrategy = struct {
    pub const Meta = struct {
        pub const name = "CountQueuingStrategy";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            highWaterMark: f64 = undefined,
            size: Function = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CountQueuingStrategy, .{
        .deinit_fn = &deinit_wrapper,

        .get_highWaterMark = &get_highWaterMark,
        .get_size = &get_size,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CountQueuingStrategyImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CountQueuingStrategyImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CountQueuingStrategyImpl.constructor(state, init);
        
        return instance;
    }

    pub fn get_highWaterMark(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return CountQueuingStrategyImpl.get_highWaterMark(state);
    }

    pub fn get_size(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CountQueuingStrategyImpl.get_size(state);
    }

};
