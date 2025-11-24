//! Generated from: turtledove.idl
//! Generated at: 2025-11-24T18:47:07Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const InterestGroupBiddingScriptRunnerGlobalScopeImpl = @import("impls").InterestGroupBiddingScriptRunnerGlobalScope;
const InterestGroupBiddingAndScoringScriptRunnerGlobalScope = @import("interfaces").InterestGroupBiddingAndScoringScriptRunnerGlobalScope;
const ProtectedAudienceUtilities = @import("interfaces").ProtectedAudienceUtilities;
const sequence = @import("interfaces").sequence;
const RealTimeReporting = @import("interfaces").RealTimeReporting;
const GenerateBidOutput = @import("dictionaries").GenerateBidOutput;
const ForDebuggingOnly = @import("interfaces").ForDebuggingOnly;
const DOMString = @import("typedefs").DOMString;
const PrivateAggregation = @import("interfaces").PrivateAggregation;

pub const InterestGroupBiddingScriptRunnerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "InterestGroupBiddingScriptRunnerGlobalScope";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *InterestGroupBiddingAndScoringScriptRunnerGlobalScope;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "InterestGroupBiddingScriptRunnerGlobalScope" } },
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "InterestGroupScriptRunnerGlobalScope", "InterestGroupBiddingScriptRunnerGlobalScope" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .InterestGroupBiddingScriptRunnerGlobalScope = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "setBid", "call_setBid", 0 },
            .{ "setPriority", "call_setPriority", 1 },
            .{ "setPrioritySignalsOverride", "call_setPrioritySignalsOverride", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setBid",
            "setPriority",
            "setPrioritySignalsOverride",
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
        struct {},
    );

    const delegates = .{

        .call_setBid = &call_setBid,
        .call_setPriority = &call_setPriority,
        .call_setPrioritySignalsOverride = &call_setPrioritySignalsOverride,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return InterestGroupBiddingScriptRunnerGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InterestGroupBiddingScriptRunnerGlobalScopeImpl.deinit(instance);
    }

    pub fn call_setBid(instance: *runtime.Instance, oneOrManyBids: *const anyopaque) anyerror!bool {
        
        return try InterestGroupBiddingScriptRunnerGlobalScopeImpl.call_setBid(instance, oneOrManyBids);
    }

    pub fn call_setPriority(instance: *runtime.Instance, priority: f64) anyerror!void {
        
        return try InterestGroupBiddingScriptRunnerGlobalScopeImpl.call_setPriority(instance, priority);
    }

    pub fn call_setPrioritySignalsOverride(instance: *runtime.Instance, key: DOMString, priority: f64) anyerror!void {
        
        return try InterestGroupBiddingScriptRunnerGlobalScopeImpl.call_setPrioritySignalsOverride(instance, key, priority);
    }

};
