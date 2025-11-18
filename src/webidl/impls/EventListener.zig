//! Implementation for EventListener interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const EventListener = @import("interfaces").EventListener;

pub const State = EventListener.State;

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

/// Operation: handleEvent
pub fn call_handleEvent(instance: *runtime.Instance, event: anyopaque) ImplError!void {
    _ = instance;
    _ = event;
    // TODO: Implement operation
    return error.NotImplemented;
}

