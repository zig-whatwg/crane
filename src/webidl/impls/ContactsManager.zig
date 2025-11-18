//! Implementation for ContactsManager interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const ContactsManager = @import("interfaces").ContactsManager;

pub const State = ContactsManager.State;

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

/// Operation: getProperties
pub fn call_getProperties(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: select
pub fn call_select(instance: *runtime.Instance, properties: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = properties;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

