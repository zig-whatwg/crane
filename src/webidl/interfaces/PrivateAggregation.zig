//! Generated from: private-aggregation-api.idl
//! Generated at: 2025-11-28T18:02:25Z
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
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "InterestGroupScriptRunnerGlobalScope", "SharedStorageWorklet" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .InterestGroupScriptRunnerGlobalScope = true,
            .SharedStorageWorklet = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "contributeToHistogram", "call_contributeToHistogram", 1 },
            .{ "contributeToHistogramOnEvent", "call_contributeToHistogramOnEvent", 2 },
            .{ "enableDebugMode", "call_enableDebugMode", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "contributeToHistogram",
            "contributeToHistogramOnEvent",
            "enableDebugMode",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*PrivateAggregationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_contributeToHistogram = &call_contributeToHistogram,
        .call_contributeToHistogramOnEvent = &call_contributeToHistogramOnEvent,
        .call_enableDebugMode = &call_enableDebugMode,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PrivateAggregationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PrivateAggregationImpl.deinit(instance);
    }

    pub fn call_contributeToHistogram(instance: *runtime.Instance, contribution: PAHistogramContribution) anyerror!void {
        
        return try PrivateAggregationImpl.call_contributeToHistogram(instance, contribution);
    }

    pub fn call_contributeToHistogramOnEvent(instance: *runtime.Instance, event: DOMString, contribution: *const anyopaque) anyerror!void {
        
        return try PrivateAggregationImpl.call_contributeToHistogramOnEvent(instance, event, contribution);
    }

    pub fn call_enableDebugMode(instance: *runtime.Instance, options: PADebugModeOptions) anyerror!void {
        
        return try PrivateAggregationImpl.call_enableDebugMode(instance, options);
    }

};
