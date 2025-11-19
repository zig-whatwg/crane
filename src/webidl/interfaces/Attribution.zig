//! Generated from: privacy-preserving-attribution.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AttributionImpl = @import("impls").Attribution;
const AttributionImpressionOptions = @import("dictionaries").AttributionImpressionOptions;
const AttributionConversionResult = @import("dictionaries").AttributionConversionResult;
const AttributionAggregationServices = @import("interfaces").AttributionAggregationServices;
const AttributionImpressionResult = @import("dictionaries").AttributionImpressionResult;
const AttributionConversionOptions = @import("dictionaries").AttributionConversionOptions;

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
        return AttributionImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AttributionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_aggregationServices(instance: *runtime.Instance) anyerror!AttributionAggregationServices {
        return try AttributionImpl.get_aggregationServices(instance);
    }

    pub fn call_measureConversion(instance: *runtime.Instance, options: AttributionConversionOptions) anyerror!anyopaque {
        
        return try AttributionImpl.call_measureConversion(instance, options);
    }

    pub fn call_saveImpression(instance: *runtime.Instance, options: AttributionImpressionOptions) anyerror!anyopaque {
        
        return try AttributionImpl.call_saveImpression(instance, options);
    }

};
