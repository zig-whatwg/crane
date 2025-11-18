//! Implementation for RTCRtpReceiver interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const RTCRtpReceiver = @import("interfaces").RTCRtpReceiver;

pub const State = RTCRtpReceiver.State;

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

/// Getter for track
pub fn get_track(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for transport
pub fn get_transport(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for jitterBufferTarget
pub fn get_jitterBufferTarget(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for transform
pub fn get_transform(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for jitterBufferTarget
pub fn set_jitterBufferTarget(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for transform
pub fn set_transform(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: getCapabilities
pub fn call_getCapabilities(instance: *runtime.Instance, kind: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = kind;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getParameters
pub fn call_getParameters(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getContributingSources
pub fn call_getContributingSources(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getSynchronizationSources
pub fn call_getSynchronizationSources(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getStats
pub fn call_getStats(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

