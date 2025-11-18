//! Generated from: turtledove.idl
//! Generated at: 2025-11-18T18:28:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ForDebuggingOnlyImpl = @import("impls").ForDebuggingOnly;

pub const ForDebuggingOnly = struct {
    pub const Meta = struct {
        pub const name = "ForDebuggingOnly";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "InterestGroupBiddingAndScoringScriptRunnerGlobalScope" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .InterestGroupBiddingAndScoringScriptRunnerGlobalScope = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ForDebuggingOnly, .{
        .deinit_fn = &deinit_wrapper,

        .call_reportAdAuctionLoss = &call_reportAdAuctionLoss,
        .call_reportAdAuctionWin = &call_reportAdAuctionWin,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ForDebuggingOnlyImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ForDebuggingOnlyImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_reportAdAuctionLoss(instance: *runtime.Instance, url: runtime.USVString) anyerror!void {
        
        return try ForDebuggingOnlyImpl.call_reportAdAuctionLoss(instance, url);
    }

    pub fn call_reportAdAuctionWin(instance: *runtime.Instance, url: runtime.USVString) anyerror!void {
        
        return try ForDebuggingOnlyImpl.call_reportAdAuctionWin(instance, url);
    }

};
