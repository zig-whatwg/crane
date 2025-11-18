//! Implementation for TrustedTypePolicy interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const TrustedTypePolicy = @import("interfaces").TrustedTypePolicy;

pub const State = TrustedTypePolicy.State;

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

/// Getter for name
pub fn get_name(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: createHTML
pub fn call_createHTML(instance: *runtime.Instance, input: runtime.DOMString, arguments: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = input;
    _ = arguments;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createScript
pub fn call_createScript(instance: *runtime.Instance, input: runtime.DOMString, arguments: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = input;
    _ = arguments;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createScriptURL
pub fn call_createScriptURL(instance: *runtime.Instance, input: runtime.DOMString, arguments: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = input;
    _ = arguments;
    // TODO: Implement operation
    return error.NotImplemented;
}

