//! Implementation for XRHitTestResult interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const XRHitTestResult = @import("interfaces").XRHitTestResult;

pub const State = XRHitTestResult.State;

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

/// Operation: getPose
pub fn call_getPose(instance: *runtime.Instance, baseSpace: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = baseSpace;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createAnchor
pub fn call_createAnchor(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

