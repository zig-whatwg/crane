//! Generated from: turtledove.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const InterestGroupScriptRunnerGlobalScopeImpl = @import("impls").InterestGroupScriptRunnerGlobalScope;
const ProtectedAudienceUtilities = @import("interfaces").ProtectedAudienceUtilities;
const PrivateAggregation = @import("interfaces").PrivateAggregation;

pub const InterestGroupScriptRunnerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "InterestGroupScriptRunnerGlobalScope";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "InterestGroupScriptRunnerGlobalScope" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .InterestGroupScriptRunnerGlobalScope = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            privateAggregation: ?PrivateAggregation = null,
            protectedAudience: ProtectedAudienceUtilities = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(InterestGroupScriptRunnerGlobalScope, .{
        .deinit_fn = &deinit_wrapper,

        .get_privateAggregation = &get_privateAggregation,
        .get_protectedAudience = &get_protectedAudience,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        InterestGroupScriptRunnerGlobalScopeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InterestGroupScriptRunnerGlobalScopeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_privateAggregation(instance: *runtime.Instance) anyerror!anyopaque {
        return try InterestGroupScriptRunnerGlobalScopeImpl.get_privateAggregation(instance);
    }

    pub fn get_protectedAudience(instance: *runtime.Instance) anyerror!ProtectedAudienceUtilities {
        return try InterestGroupScriptRunnerGlobalScopeImpl.get_protectedAudience(instance);
    }

};
