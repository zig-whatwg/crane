//! Generated from: private-aggregation-api.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PrivateAggregationImpl = @import("impls").PrivateAggregation;
const PAHistogramContribution = @import("dictionaries").PAHistogramContribution;
const PADebugModeOptions = @import("dictionaries").PADebugModeOptions;
const DOMString = @import("typedefs").DOMString;

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
        return PrivateAggregationImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PrivateAggregationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_contributeToHistogram(instance: *runtime.Instance, contribution: PAHistogramContribution) anyerror!void {
        
        return try PrivateAggregationImpl.call_contributeToHistogram(instance, contribution);
    }

    pub fn call_contributeToHistogramOnEvent(instance: *runtime.Instance, event: DOMString, contribution: anyopaque) anyerror!void {
        
        return try PrivateAggregationImpl.call_contributeToHistogramOnEvent(instance, event, contribution);
    }

    pub fn call_enableDebugMode(instance: *runtime.Instance, options: PADebugModeOptions) anyerror!void {
        
        return try PrivateAggregationImpl.call_enableDebugMode(instance, options);
    }

};
