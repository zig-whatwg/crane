//! Generated from: turtledove.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const InterestGroupReportingScriptRunnerGlobalScopeImpl = @import("../impls/InterestGroupReportingScriptRunnerGlobalScope.zig");
const InterestGroupScriptRunnerGlobalScope = @import("InterestGroupScriptRunnerGlobalScope.zig");

pub const InterestGroupReportingScriptRunnerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "InterestGroupReportingScriptRunnerGlobalScope";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *InterestGroupScriptRunnerGlobalScope;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "InterestGroupReportingScriptRunnerGlobalScope" } },
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "InterestGroupScriptRunnerGlobalScope", "InterestGroupReportingScriptRunnerGlobalScope" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .InterestGroupReportingScriptRunnerGlobalScope = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(InterestGroupReportingScriptRunnerGlobalScope, .{
        .deinit_fn = &deinit_wrapper,

        .get_privateAggregation = &get_privateAggregation,
        .get_protectedAudience = &get_protectedAudience,

        .call_registerAdBeacon = &call_registerAdBeacon,
        .call_registerAdMacro = &call_registerAdMacro,
        .call_sendReportTo = &call_sendReportTo,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        InterestGroupReportingScriptRunnerGlobalScopeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        InterestGroupReportingScriptRunnerGlobalScopeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_privateAggregation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return InterestGroupReportingScriptRunnerGlobalScopeImpl.get_privateAggregation(state);
    }

    pub fn get_protectedAudience(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return InterestGroupReportingScriptRunnerGlobalScopeImpl.get_protectedAudience(state);
    }

    pub fn call_registerAdMacro(instance: *runtime.Instance, name: runtime.DOMString, value: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return InterestGroupReportingScriptRunnerGlobalScopeImpl.call_registerAdMacro(state, name, value);
    }

    pub fn call_registerAdBeacon(instance: *runtime.Instance, map: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return InterestGroupReportingScriptRunnerGlobalScopeImpl.call_registerAdBeacon(state, map);
    }

    pub fn call_sendReportTo(instance: *runtime.Instance, url: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return InterestGroupReportingScriptRunnerGlobalScopeImpl.call_sendReportTo(state, url);
    }

};
