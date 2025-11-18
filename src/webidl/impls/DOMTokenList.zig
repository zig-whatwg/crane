//! Implementation for DOMTokenList interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const DOMTokenList = @import("interfaces").DOMTokenList;

pub const State = DOMTokenList.State;

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

/// Getter for length
pub fn get_length(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for value
pub fn get_value(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for value
pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: item
pub fn call_item(instance: *runtime.Instance, index: u32) ImplError!anyopaque {
    _ = instance;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: contains
pub fn call_contains(instance: *runtime.Instance, token: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = token;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: add
pub fn call_add(instance: *runtime.Instance, tokens: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = tokens;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: remove
pub fn call_remove(instance: *runtime.Instance, tokens: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = tokens;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: toggle
pub fn call_toggle(instance: *runtime.Instance, token: runtime.DOMString, force: bool) ImplError!bool {
    _ = instance;
    _ = token;
    _ = force;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: replace
pub fn call_replace(instance: *runtime.Instance, token: runtime.DOMString, newToken: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = token;
    _ = newToken;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: supports
pub fn call_supports(instance: *runtime.Instance, token: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = token;
    // TODO: Implement operation
    return error.NotImplemented;
}

