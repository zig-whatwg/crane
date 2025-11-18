//! Implementation for WindowClient interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WindowClient = @import("interfaces").WindowClient;

pub const State = WindowClient.State;

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

/// Getter for url
pub fn get_url(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for frameType
pub fn get_frameType(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for id
pub fn get_id(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for lifecycleState
pub fn get_lifecycleState(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for visibilityState
pub fn get_visibilityState(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for focused
pub fn get_focused(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ancestorOrigins
pub fn get_ancestorOrigins(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: postMessage
pub fn call_postMessage(instance: *runtime.Instance, message: anyopaque, transfer: anyopaque) ImplError!void {
    _ = instance;
    _ = message;
    _ = transfer;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: postMessage
pub fn call_postMessage(instance: *runtime.Instance, message: anyopaque, options: anyopaque) ImplError!void {
    _ = instance;
    _ = message;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: focus
pub fn call_focus(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: navigate
pub fn call_navigate(instance: *runtime.Instance, url: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = url;
    // TODO: Implement operation
    return error.NotImplemented;
}

