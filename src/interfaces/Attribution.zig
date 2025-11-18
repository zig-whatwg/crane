//! Generated from: privacy-preserving-attribution.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AttributionImpl = @import("../impls/Attribution.zig");

pub const Attribution = struct {
    pub const Meta = struct {
        pub const name = "Attribution";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            aggregationServices: AttributionAggregationServices = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Attribution, .{
        .deinit_fn = &deinit_wrapper,

        .get_aggregationServices = &get_aggregationServices,

        .call_measureConversion = &call_measureConversion,
        .call_saveImpression = &call_saveImpression,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        AttributionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AttributionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_aggregationServices(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AttributionImpl.get_aggregationServices(state);
    }

    pub fn call_measureConversion(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AttributionImpl.call_measureConversion(state, options);
    }

    pub fn call_saveImpression(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AttributionImpl.call_saveImpression(state, options);
    }

};
