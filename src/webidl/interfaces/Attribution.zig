//! Generated from: privacy-preserving-attribution.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AttributionImpl = @import("impls").Attribution;
const mixins = @import("mixins");
const AttributionImpressionOptions = @import("dictionaries").AttributionImpressionOptions;
const AttributionConversionResult = @import("dictionaries").AttributionConversionResult;
const AttributionAggregationServices = @import("interfaces").AttributionAggregationServices;
const AttributionImpressionResult = @import("dictionaries").AttributionImpressionResult;
const AttributionConversionOptions = @import("dictionaries").AttributionConversionOptions;

pub const Attribution = struct {
    pub const Meta = struct {
        pub const name = "Attribution";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "aggregationServices", "get_aggregationServices", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "saveImpression", "call_saveImpression", 1 },
            .{ "measureConversion", "call_measureConversion", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "saveImpression",
            "measureConversion",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "aggregationServices", "get_aggregationServices", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            aggregationServices: *runtime.Instance = undefined,
            _internal: ?*AttributionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_aggregationServices = &get_aggregationServices,

        .call_measureConversion = &call_measureConversion,
        .call_saveImpression = &call_saveImpression,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AttributionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AttributionImpl.deinit(instance);
    }

    pub fn get_aggregationServices(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AttributionImpl.get_aggregationServices(instance);
    }

    pub fn call_measureConversion(instance: *runtime.Instance, options: AttributionConversionOptions) anyerror!*const anyopaque {
        
        return try AttributionImpl.call_measureConversion(instance, options);
    }

    pub fn call_saveImpression(instance: *runtime.Instance, options: AttributionImpressionOptions) anyerror!*const anyopaque {
        
        return try AttributionImpl.call_saveImpression(instance, options);
    }

};
