//! Implementation for RTCRtpSender interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const RTCRtpSender = @import("interfaces").RTCRtpSender;

pub const State = RTCRtpSender.State;

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

/// Getter for dtmf
pub fn get_dtmf(instance: *runtime.Instance) ImplError!anyopaque {
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

/// Operation: setParameters
pub fn call_setParameters(instance: *runtime.Instance, parameters: anyopaque, setParameterOptions: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = parameters;
    _ = setParameterOptions;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getParameters
pub fn call_getParameters(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: replaceTrack
pub fn call_replaceTrack(instance: *runtime.Instance, withTrack: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = withTrack;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setStreams
pub fn call_setStreams(instance: *runtime.Instance, streams: anyopaque) ImplError!void {
    _ = instance;
    _ = streams;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getStats
pub fn call_getStats(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

