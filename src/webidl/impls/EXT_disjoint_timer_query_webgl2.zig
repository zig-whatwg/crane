//! Implementation for EXT_disjoint_timer_query_webgl2 interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const EXT_disjoint_timer_query_webgl2 = @import("interfaces").EXT_disjoint_timer_query_webgl2;

pub const State = EXT_disjoint_timer_query_webgl2.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Operation: queryCounterEXT
pub fn call_queryCounterEXT(instance: *runtime.Instance, query: anyopaque, target: anyopaque) ImplError!void {
    _ = instance;
    _ = query;
    _ = target;
    // TODO: Implement operation
    return error.NotImplemented;
}

