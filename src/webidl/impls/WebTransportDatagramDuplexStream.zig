//! Implementation for WebTransportDatagramDuplexStream interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportDatagramDuplexStream = @import("interfaces").WebTransportDatagramDuplexStream;

pub const State = WebTransportDatagramDuplexStream.State;

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

/// Getter for readable
pub fn get_readable(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxDatagramSize
pub fn get_maxDatagramSize(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for incomingMaxAge
pub fn get_incomingMaxAge(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for outgoingMaxAge
pub fn get_outgoingMaxAge(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for incomingHighWaterMark
pub fn get_incomingHighWaterMark(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for outgoingHighWaterMark
pub fn get_outgoingHighWaterMark(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for incomingMaxAge
pub fn set_incomingMaxAge(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for outgoingMaxAge
pub fn set_outgoingMaxAge(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for incomingHighWaterMark
pub fn set_incomingHighWaterMark(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for outgoingHighWaterMark
pub fn set_outgoingHighWaterMark(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: createWritable
pub fn call_createWritable(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

