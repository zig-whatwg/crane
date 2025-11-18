//! Implementation for History interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const History = @import("interfaces").History;

pub const State = History.State;

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

/// Getter for scrollRestoration
pub fn get_scrollRestoration(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for state
pub fn get_state(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for scrollRestoration
pub fn set_scrollRestoration(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: go
pub fn call_go(instance: *runtime.Instance, delta: i32) ImplError!void {
    _ = instance;
    _ = delta;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: back
pub fn call_back(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: forward
pub fn call_forward(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: pushState
pub fn call_pushState(instance: *runtime.Instance, data: anyopaque, unused: runtime.DOMString, url: anyopaque) ImplError!void {
    _ = instance;
    _ = data;
    _ = unused;
    _ = url;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: replaceState
pub fn call_replaceState(instance: *runtime.Instance, data: anyopaque, unused: runtime.DOMString, url: anyopaque) ImplError!void {
    _ = instance;
    _ = data;
    _ = unused;
    _ = url;
    // TODO: Implement operation
    return error.NotImplemented;
}

