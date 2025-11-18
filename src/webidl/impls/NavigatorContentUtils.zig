//! Implementation for NavigatorContentUtils interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorContentUtils = @import("interfaces").NavigatorContentUtils;

pub const State = NavigatorContentUtils.State;

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

/// Operation: registerProtocolHandler
pub fn call_registerProtocolHandler(instance: *runtime.Instance, scheme: runtime.DOMString, url: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = scheme;
    _ = url;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: unregisterProtocolHandler
pub fn call_unregisterProtocolHandler(instance: *runtime.Instance, scheme: runtime.DOMString, url: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = scheme;
    _ = url;
    // TODO: Implement operation
    return error.NotImplemented;
}

