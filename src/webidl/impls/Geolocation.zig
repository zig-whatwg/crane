//! Implementation for Geolocation interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const Geolocation = @import("interfaces").Geolocation;

pub const State = Geolocation.State;

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

/// Operation: getCurrentPosition
pub fn call_getCurrentPosition(instance: *runtime.Instance, successCallback: anyopaque, errorCallback: anyopaque, options: anyopaque) ImplError!void {
    _ = instance;
    _ = successCallback;
    _ = errorCallback;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: watchPosition
pub fn call_watchPosition(instance: *runtime.Instance, successCallback: anyopaque, errorCallback: anyopaque, options: anyopaque) ImplError!i32 {
    _ = instance;
    _ = successCallback;
    _ = errorCallback;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clearWatch
pub fn call_clearWatch(instance: *runtime.Instance, watchId: i32) ImplError!void {
    _ = instance;
    _ = watchId;
    // TODO: Implement operation
    return error.NotImplemented;
}

