//! Implementation for EXT_disjoint_timer_query interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const EXT_disjoint_timer_query = @import("interfaces").EXT_disjoint_timer_query;

pub const State = EXT_disjoint_timer_query.State;

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

/// Operation: createQueryEXT
pub fn call_createQueryEXT(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteQueryEXT
pub fn call_deleteQueryEXT(instance: *runtime.Instance, query: anyopaque) ImplError!void {
    _ = instance;
    _ = query;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isQueryEXT
pub fn call_isQueryEXT(instance: *runtime.Instance, query: anyopaque) ImplError!bool {
    _ = instance;
    _ = query;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: beginQueryEXT
pub fn call_beginQueryEXT(instance: *runtime.Instance, target: anyopaque, query: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = query;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: endQueryEXT
pub fn call_endQueryEXT(instance: *runtime.Instance, target: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: queryCounterEXT
pub fn call_queryCounterEXT(instance: *runtime.Instance, query: anyopaque, target: anyopaque) ImplError!void {
    _ = instance;
    _ = query;
    _ = target;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getQueryEXT
pub fn call_getQueryEXT(instance: *runtime.Instance, target: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = target;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getQueryObjectEXT
pub fn call_getQueryObjectEXT(instance: *runtime.Instance, query: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = query;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

