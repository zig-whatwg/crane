//! Generated from: streams.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CountQueuingStrategyImpl = @import("impls").CountQueuingStrategy;
const Function = @import("callbacks").Function;
const QueuingStrategyInit = @import("dictionaries").QueuingStrategyInit;

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
        
        // Initialize the instance (Impl receives full instance)
        CountQueuingStrategyImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CountQueuingStrategyImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: QueuingStrategyInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CountQueuingStrategyImpl.constructor(instance, init);
        
        return instance;
    }

    pub fn get_highWaterMark(instance: *runtime.Instance) anyerror!f64 {
        return try CountQueuingStrategyImpl.get_highWaterMark(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!Function {
        return try CountQueuingStrategyImpl.get_size(instance);
    }

};
