//! Implementation for SharedStorageWorkletGlobalScope interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const SharedStorageWorkletGlobalScope = @import("interfaces").SharedStorageWorkletGlobalScope;

pub const State = SharedStorageWorkletGlobalScope.State;

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

/// Getter for sharedStorage
pub fn get_sharedStorage(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for privateAggregation
pub fn get_privateAggregation(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for navigator
pub fn get_navigator(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: register
pub fn call_register(instance: *runtime.Instance, name: runtime.DOMString, operationCtor: anyopaque) ImplError!void {
    _ = instance;
    _ = name;
    _ = operationCtor;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: interestGroups
pub fn call_interestGroups(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

