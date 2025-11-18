//! Implementation for Ink interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const Ink = @import("interfaces").Ink;

pub const State = Ink.State;

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

/// Operation: requestPresenter
pub fn call_requestPresenter(instance: *runtime.Instance, param: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = param;
    // TODO: Implement operation
    return error.NotImplemented;
}

