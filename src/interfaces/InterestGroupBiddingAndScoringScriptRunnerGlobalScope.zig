//! Generated from: turtledove.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl = @import("../impls/InterestGroupBiddingAndScoringScriptRunnerGlobalScope.zig");
const InterestGroupScriptRunnerGlobalScope = @import("InterestGroupScriptRunnerGlobalScope.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_privateAggregation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.get_privateAggregation(state);
    }

    pub fn get_protectedAudience(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.get_protectedAudience(state);
    }

    pub fn get_forDebuggingOnly(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.get_forDebuggingOnly(state);
    }

    pub fn get_realTimeReporting(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.get_realTimeReporting(state);
    }

};
