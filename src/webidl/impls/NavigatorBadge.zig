//! Implementation for NavigatorBadge interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorBadge = @import("interfaces").NavigatorBadge;

pub const State = NavigatorBadge.State;

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

/// Operation: setAppBadge
pub fn call_setAppBadge(instance: *runtime.Instance, contents: u64) ImplError!anyopaque {
    _ = instance;
    _ = contents;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clearAppBadge
pub fn call_clearAppBadge(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

