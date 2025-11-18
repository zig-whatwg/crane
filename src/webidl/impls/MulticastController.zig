//! Implementation for MulticastController interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const MulticastController = @import("interfaces").MulticastController;

pub const State = MulticastController.State;

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

/// Getter for joinedGroups
pub fn get_joinedGroups(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: joinGroup
pub fn call_joinGroup(instance: *runtime.Instance, ipAddress: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = ipAddress;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: leaveGroup
pub fn call_leaveGroup(instance: *runtime.Instance, ipAddress: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = ipAddress;
    // TODO: Implement operation
    return error.NotImplemented;
}

