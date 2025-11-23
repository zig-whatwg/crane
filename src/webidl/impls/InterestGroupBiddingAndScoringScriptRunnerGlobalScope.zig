//! Implementation for InterestGroupBiddingAndScoringScriptRunnerGlobalScope interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const InterestGroupBiddingAndScoringScriptRunnerGlobalScope = interfaces.InterestGroupBiddingAndScoringScriptRunnerGlobalScope;

pub const State = InterestGroupBiddingAndScoringScriptRunnerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Getter for forDebuggingOnly
pub fn get_forDebuggingOnly(instance: *runtime.Instance) ImplError!interfaces.ForDebuggingOnly {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for realTimeReporting
pub fn get_realTimeReporting(instance: *runtime.Instance) ImplError!interfaces.RealTimeReporting {
    _ = instance;
    return error.NotImplemented;
}

