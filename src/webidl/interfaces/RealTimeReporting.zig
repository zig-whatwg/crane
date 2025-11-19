//! Generated from: turtledove.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RealTimeReportingImpl = @import("impls").RealTimeReporting;
const RealTimeContribution = @import("dictionaries").RealTimeContribution;

pub const RealTimeReporting = struct {
    pub const Meta = struct {
        pub const name = "RealTimeReporting";
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

    pub const vtable = runtime.buildVTable(RealTimeReporting, .{
        .deinit_fn = &deinit_wrapper,

        .call_contributeToHistogram = &call_contributeToHistogram,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return RealTimeReportingImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RealTimeReportingImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_contributeToHistogram(instance: *runtime.Instance, contribution: RealTimeContribution) anyerror!void {
        
        return try RealTimeReportingImpl.call_contributeToHistogram(instance, contribution);
    }

};
