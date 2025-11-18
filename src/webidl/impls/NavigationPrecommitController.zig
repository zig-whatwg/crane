//! Implementation for NavigationPrecommitController interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const NavigationPrecommitController = @import("interfaces").NavigationPrecommitController;

pub const State = NavigationPrecommitController.State;

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

/// Operation: redirect
pub fn call_redirect(instance: *runtime.Instance, url: runtime.DOMString, options: anyopaque) ImplError!void {
    _ = instance;
    _ = url;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

