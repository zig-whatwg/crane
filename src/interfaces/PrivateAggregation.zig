//! Generated from: private-aggregation-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PrivateAggregationImpl = @import("../impls/PrivateAggregation.zig");

pub const PrivateAggregation = struct {
    pub const Meta = struct {
        pub const name = "PrivateAggregation";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "InterestGroupScriptRunnerGlobalScope", "SharedStorageWorklet" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .InterestGroupScriptRunnerGlobalScope = true,
            .SharedStorageWorklet = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PrivateAggregation, .{
        .deinit_fn = &deinit_wrapper,

        .call_contributeToHistogram = &call_contributeToHistogram,
        .call_contributeToHistogramOnEvent = &call_contributeToHistogramOnEvent,
        .call_enableDebugMode = &call_enableDebugMode,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        PrivateAggregationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PrivateAggregationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_contributeToHistogram(instance: *runtime.Instance, contribution: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PrivateAggregationImpl.call_contributeToHistogram(state, contribution);
    }

    pub fn call_contributeToHistogramOnEvent(instance: *runtime.Instance, event: runtime.DOMString, contribution: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PrivateAggregationImpl.call_contributeToHistogramOnEvent(state, event, contribution);
    }

    pub fn call_enableDebugMode(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PrivateAggregationImpl.call_enableDebugMode(state, options);
    }

};
