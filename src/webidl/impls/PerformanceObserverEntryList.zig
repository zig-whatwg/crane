//! Implementation for PerformanceObserverEntryList interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceObserverEntryList = @import("interfaces").PerformanceObserverEntryList;

pub const State = PerformanceObserverEntryList.State;

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

/// Operation: getEntries
pub fn call_getEntries(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getEntriesByType
pub fn call_getEntriesByType(instance: *runtime.Instance, type: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = type;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getEntriesByName
pub fn call_getEntriesByName(instance: *runtime.Instance, name: runtime.DOMString, type: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = name;
    _ = type;
    // TODO: Implement operation
    return error.NotImplemented;
}

