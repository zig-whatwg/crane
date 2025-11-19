//! Implementation for InterestGroupBiddingScriptRunnerGlobalScope interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const InterestGroupBiddingScriptRunnerGlobalScope = @import("interfaces").InterestGroupBiddingScriptRunnerGlobalScope;

pub const State = InterestGroupBiddingScriptRunnerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance (delegates to runtime.Instance.init)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable);
    // TODO: Add custom initialization here if needed
    // const state = instance.getState(StateType);
    // state.* = .{}; // Initialize fields
    return instance;
}

/// Deinitialize instance (delegates to runtime.Instance.deinit)
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Add custom cleanup here if needed
    // const state = instance.getState(State);
    // Clean up fields...
    runtime.Instance.deinit(instance);
}

/// Getter for privateAggregation
pub fn get_privateAggregation(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for protectedAudience
pub fn get_protectedAudience(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for forDebuggingOnly
pub fn get_forDebuggingOnly(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for realTimeReporting
pub fn get_realTimeReporting(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: setBid
pub fn call_setBid(instance: *runtime.Instance, oneOrManyBids: anyopaque) ImplError!bool {
    _ = instance;
    _ = oneOrManyBids;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setPriority
pub fn call_setPriority(instance: *runtime.Instance, priority: f64) ImplError!void {
    _ = instance;
    _ = priority;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setPrioritySignalsOverride
pub fn call_setPrioritySignalsOverride(instance: *runtime.Instance, key: runtime.DOMString, priority: f64) ImplError!void {
    _ = instance;
    _ = key;
    _ = priority;
    // TODO: Implement operation
    return error.NotImplemented;
}

