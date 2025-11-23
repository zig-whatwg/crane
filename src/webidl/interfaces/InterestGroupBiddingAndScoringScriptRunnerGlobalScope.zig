//! Generated from: turtledove.idl
//! Generated at: 2025-11-23T19:47:43Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl = @import("impls").InterestGroupBiddingAndScoringScriptRunnerGlobalScope;
const InterestGroupScriptRunnerGlobalScope = @import("interfaces").InterestGroupScriptRunnerGlobalScope;
const RealTimeReporting = @import("interfaces").RealTimeReporting;
const PrivateAggregation = @import("interfaces").PrivateAggregation;
const ForDebuggingOnly = @import("interfaces").ForDebuggingOnly;
const ProtectedAudienceUtilities = @import("interfaces").ProtectedAudienceUtilities;

pub const InterestGroupBiddingAndScoringScriptRunnerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "InterestGroupBiddingAndScoringScriptRunnerGlobalScope";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *InterestGroupScriptRunnerGlobalScope;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "InterestGroupBiddingAndScoringScriptRunnerGlobalScope" } },
            .{ .name = "Global", .value = .{ .identifier = "InterestGroupBiddingAndScoringScriptRunnerGlobalScope" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .InterestGroupBiddingAndScoringScriptRunnerGlobalScope = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "forDebuggingOnly", "get_forDebuggingOnly", null },
            .{ "realTimeReporting", "get_realTimeReporting", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "forDebuggingOnly", "get_forDebuggingOnly", null },
            .{ "realTimeReporting", "get_realTimeReporting", null },
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
            forDebuggingOnly: *runtime.Instance = undefined,
            realTimeReporting: *runtime.Instance = undefined,
            _internal: ?*InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_forDebuggingOnly = &get_forDebuggingOnly,
        .get_realTimeReporting = &get_realTimeReporting,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.deinit(instance);
    }

    pub fn get_forDebuggingOnly(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.get_forDebuggingOnly(instance);
    }

    pub fn get_realTimeReporting(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.get_realTimeReporting(instance);
    }

};
