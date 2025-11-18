//! Implementation for ViewCSS interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const ViewCSS = @import("interfaces").ViewCSS;

pub const State = ViewCSS.State;

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

/// Operation: getComputedStyle
pub fn call_getComputedStyle(instance: *runtime.Instance, elt: anyopaque, pseudoElt: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = elt;
    _ = pseudoElt;
    // TODO: Implement operation
    return error.NotImplemented;
}

