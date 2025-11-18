//! Implementation for Serial interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const Serial = @import("interfaces").Serial;

pub const State = Serial.State;

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

/// Constructor implementation
pub fn constructor(instance: *runtime.Instance) !void {
    _ = instance;
    // TODO: Implement constructor logic
}

/// Getter for onconnect
pub fn get_onconnect(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ondisconnect
pub fn get_ondisconnect(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for onconnect
pub fn set_onconnect(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for ondisconnect
pub fn set_ondisconnect(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: addEventListener
pub fn call_addEventListener(instance: *runtime.Instance, type: runtime.DOMString, callback: anyopaque, options: anyopaque) ImplError!void {
    _ = instance;
    _ = type;
    _ = callback;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeEventListener
pub fn call_removeEventListener(instance: *runtime.Instance, type: runtime.DOMString, callback: anyopaque, options: anyopaque) ImplError!void {
    _ = instance;
    _ = type;
    _ = callback;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dispatchEvent
pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) ImplError!bool {
    _ = instance;
    _ = event;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: when
pub fn call_when(instance: *runtime.Instance, type: runtime.DOMString, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = type;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getPorts
pub fn call_getPorts(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: requestPort
pub fn call_requestPort(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

