//! Implementation for Clients interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const Clients = @import("interfaces").Clients;

pub const State = Clients.State;

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

/// Operation: get
pub fn call_get(instance: *runtime.Instance, id: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = id;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: matchAll
pub fn call_matchAll(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: openWindow
pub fn call_openWindow(instance: *runtime.Instance, url: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = url;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: claim
pub fn call_claim(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

