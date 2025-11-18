//! Generated from: turtledove.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl = @import("impls").InterestGroupBiddingAndScoringScriptRunnerGlobalScope;
const InterestGroupScriptRunnerGlobalScope = @import("interfaces").InterestGroupScriptRunnerGlobalScope;
const RealTimeReporting = @import("interfaces").RealTimeReporting;
const ForDebuggingOnly = @import("interfaces").ForDebuggingOnly;

pub const InterestGroupBiddingAndScoringScriptRunnerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "InterestGroupBiddingAndScoringScriptRunnerGlobalScope";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *InterestGroupScriptRunnerGlobalScope;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "InterestGroupBiddingAndScoringScriptRunnerGlobalScope" } },
            .{ .name = "Global", .value = .{ .identifier = "InterestGroupBiddingAndScoringScriptRunnerGlobalScope" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .InterestGroupBiddingAndScoringScriptRunnerGlobalScope = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            forDebuggingOnly: ForDebuggingOnly = undefined,
            realTimeReporting: RealTimeReporting = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(InterestGroupBiddingAndScoringScriptRunnerGlobalScope, .{
        .deinit_fn = &deinit_wrapper,

        .get_forDebuggingOnly = &get_forDebuggingOnly,
        .get_privateAggregation = &get_privateAggregation,
        .get_protectedAudience = &get_protectedAudience,
        .get_realTimeReporting = &get_realTimeReporting,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_privateAggregation(instance: *runtime.Instance) anyerror!anyopaque {
        return try InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.get_privateAggregation(instance);
    }

    pub fn get_protectedAudience(instance: *runtime.Instance) anyerror!ProtectedAudienceUtilities {
        return try InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.get_protectedAudience(instance);
    }

    pub fn get_forDebuggingOnly(instance: *runtime.Instance) anyerror!ForDebuggingOnly {
        return try InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.get_forDebuggingOnly(instance);
    }

    pub fn get_realTimeReporting(instance: *runtime.Instance) anyerror!RealTimeReporting {
        return try InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.get_realTimeReporting(instance);
    }

};
