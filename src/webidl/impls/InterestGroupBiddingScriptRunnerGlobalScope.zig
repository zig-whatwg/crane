//! Implementation for InterestGroupBiddingScriptRunnerGlobalScope interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const InterestGroupBiddingScriptRunnerGlobalScope = interfaces.InterestGroupBiddingScriptRunnerGlobalScope;

pub const State = InterestGroupBiddingScriptRunnerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

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

/// Operation: setBid
pub fn call_setBid(instance: *runtime.Instance, oneOrManyBids: webidl.Opt(*const anyopaque)) anyerror!bool {
    _ = instance;
    _ = oneOrManyBids;
    return error.NotImplemented;
}

/// Operation: setPriority
pub fn call_setPriority(instance: *runtime.Instance, priority: f64) anyerror!void {
    _ = instance;
    _ = priority;
    return error.NotImplemented;
}

/// Operation: setPrioritySignalsOverride
pub fn call_setPrioritySignalsOverride(instance: *runtime.Instance, key: runtime.DOMString, priority: webidl.Opt(?f64)) anyerror!void {
    _ = instance;
    _ = key;
    _ = priority;
    return error.NotImplemented;
}

