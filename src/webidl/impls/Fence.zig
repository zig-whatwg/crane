//! Implementation for Fence interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const Fence = @import("interfaces").Fence;

pub const State = Fence.State;

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

/// Operation: reportEvent
pub fn call_reportEvent(instance: *runtime.Instance, event: anyopaque) ImplError!void {
    _ = instance;
    _ = event;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setReportEventDataForAutomaticBeacons
pub fn call_setReportEventDataForAutomaticBeacons(instance: *runtime.Instance, event: anyopaque) ImplError!void {
    _ = instance;
    _ = event;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getNestedConfigs
pub fn call_getNestedConfigs(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: disableUntrustedNetwork
pub fn call_disableUntrustedNetwork(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: notifyEvent
pub fn call_notifyEvent(instance: *runtime.Instance, event: anyopaque) ImplError!void {
    _ = instance;
    _ = event;
    // TODO: Implement operation
    return error.NotImplemented;
}

