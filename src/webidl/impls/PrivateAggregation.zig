//! Implementation for PrivateAggregation interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const PrivateAggregation = @import("interfaces").PrivateAggregation;

pub const State = PrivateAggregation.State;

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

/// Operation: contributeToHistogram
pub fn call_contributeToHistogram(instance: *runtime.Instance, contribution: anyopaque) ImplError!void {
    _ = instance;
    _ = contribution;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: contributeToHistogramOnEvent
pub fn call_contributeToHistogramOnEvent(instance: *runtime.Instance, event: runtime.DOMString, contribution: anyopaque) ImplError!void {
    _ = instance;
    _ = event;
    _ = contribution;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: enableDebugMode
pub fn call_enableDebugMode(instance: *runtime.Instance, options: anyopaque) ImplError!void {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

