//! Implementation for CSSImageValue interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CSSImageValue = @import("interfaces").CSSImageValue;

pub const State = CSSImageValue.State;

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

/// Operation: unnamed
pub fn call_unnamed(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: parse
pub fn call_parse(instance: *runtime.Instance, property: runtime.DOMString, cssText: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = property;
    _ = cssText;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: parseAll
pub fn call_parseAll(instance: *runtime.Instance, property: runtime.DOMString, cssText: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = property;
    _ = cssText;
    // TODO: Implement operation
    return error.NotImplemented;
}

