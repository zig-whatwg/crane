//! Generated from: turtledove.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const InterestGroupBiddingScriptRunnerGlobalScopeImpl = @import("../impls/InterestGroupBiddingScriptRunnerGlobalScope.zig");
const InterestGroupBiddingAndScoringScriptRunnerGlobalScope = @import("InterestGroupBiddingAndScoringScriptRunnerGlobalScope.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        InterestGroupBiddingScriptRunnerGlobalScopeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        InterestGroupBiddingScriptRunnerGlobalScopeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_privateAggregation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return InterestGroupBiddingScriptRunnerGlobalScopeImpl.get_privateAggregation(state);
    }

    pub fn get_protectedAudience(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return InterestGroupBiddingScriptRunnerGlobalScopeImpl.get_protectedAudience(state);
    }

    pub fn get_forDebuggingOnly(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return InterestGroupBiddingScriptRunnerGlobalScopeImpl.get_forDebuggingOnly(state);
    }

    pub fn get_realTimeReporting(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return InterestGroupBiddingScriptRunnerGlobalScopeImpl.get_realTimeReporting(state);
    }

    pub fn call_setBid(instance: *runtime.Instance, oneOrManyBids: anyopaque) bool {
        const state = instance.getState(State);
        
        return InterestGroupBiddingScriptRunnerGlobalScopeImpl.call_setBid(state, oneOrManyBids);
    }

    pub fn call_setPriority(instance: *runtime.Instance, priority: f64) anyopaque {
        const state = instance.getState(State);
        
        return InterestGroupBiddingScriptRunnerGlobalScopeImpl.call_setPriority(state, priority);
    }

    pub fn call_setPrioritySignalsOverride(instance: *runtime.Instance, key: runtime.DOMString, priority: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return InterestGroupBiddingScriptRunnerGlobalScopeImpl.call_setPrioritySignalsOverride(state, key, priority);
    }

};
