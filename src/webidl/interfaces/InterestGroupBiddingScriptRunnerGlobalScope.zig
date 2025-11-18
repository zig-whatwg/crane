//! Generated from: turtledove.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const InterestGroupBiddingScriptRunnerGlobalScopeImpl = @import("impls").InterestGroupBiddingScriptRunnerGlobalScope;
const InterestGroupBiddingAndScoringScriptRunnerGlobalScope = @import("interfaces").InterestGroupBiddingAndScoringScriptRunnerGlobalScope;
const (GenerateBidOutput or sequence) = @import("interfaces").(GenerateBidOutput or sequence);
const double = @import("interfaces").double;

pub const InterestGroupBiddingScriptRunnerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "InterestGroupBiddingScriptRunnerGlobalScope";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *InterestGroupBiddingAndScoringScriptRunnerGlobalScope;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "InterestGroupBiddingScriptRunnerGlobalScope" } },
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "InterestGroupScriptRunnerGlobalScope", "InterestGroupBiddingScriptRunnerGlobalScope" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .InterestGroupBiddingScriptRunnerGlobalScope = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(InterestGroupBiddingScriptRunnerGlobalScope, .{
        .deinit_fn = &deinit_wrapper,

        .get_forDebuggingOnly = &get_forDebuggingOnly,
        .get_privateAggregation = &get_privateAggregation,
        .get_protectedAudience = &get_protectedAudience,
        .get_realTimeReporting = &get_realTimeReporting,

        .call_setBid = &call_setBid,
        .call_setPriority = &call_setPriority,
        .call_setPrioritySignalsOverride = &call_setPrioritySignalsOverride,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        InterestGroupBiddingScriptRunnerGlobalScopeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InterestGroupBiddingScriptRunnerGlobalScopeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_privateAggregation(instance: *runtime.Instance) anyerror!anyopaque {
        return try InterestGroupBiddingScriptRunnerGlobalScopeImpl.get_privateAggregation(instance);
    }

    pub fn get_protectedAudience(instance: *runtime.Instance) anyerror!ProtectedAudienceUtilities {
        return try InterestGroupBiddingScriptRunnerGlobalScopeImpl.get_protectedAudience(instance);
    }

    pub fn get_forDebuggingOnly(instance: *runtime.Instance) anyerror!ForDebuggingOnly {
        return try InterestGroupBiddingScriptRunnerGlobalScopeImpl.get_forDebuggingOnly(instance);
    }

    pub fn get_realTimeReporting(instance: *runtime.Instance) anyerror!RealTimeReporting {
        return try InterestGroupBiddingScriptRunnerGlobalScopeImpl.get_realTimeReporting(instance);
    }

    pub fn call_setBid(instance: *runtime.Instance, oneOrManyBids: anyopaque) anyerror!bool {
        
        return try InterestGroupBiddingScriptRunnerGlobalScopeImpl.call_setBid(instance, oneOrManyBids);
    }

    pub fn call_setPriority(instance: *runtime.Instance, priority: f64) anyerror!void {
        
        return try InterestGroupBiddingScriptRunnerGlobalScopeImpl.call_setPriority(instance, priority);
    }

    pub fn call_setPrioritySignalsOverride(instance: *runtime.Instance, key: DOMString, priority: anyopaque) anyerror!void {
        
        return try InterestGroupBiddingScriptRunnerGlobalScopeImpl.call_setPrioritySignalsOverride(instance, key, priority);
    }

};
