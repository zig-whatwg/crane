//! Implementation for DocumentCSS interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const DocumentCSS = @import("interfaces").DocumentCSS;

pub const State = DocumentCSS.State;

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

/// Getter for styleSheets
pub fn get_styleSheets(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: getOverrideStyle
pub fn call_getOverrideStyle(instance: *runtime.Instance, elt: anyopaque, pseudoElt: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = elt;
    _ = pseudoElt;
    // TODO: Implement operation
    return error.NotImplemented;
}

