//! Implementation for AudioParam interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const AudioParam = @import("interfaces").AudioParam;

pub const State = AudioParam.State;

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

/// Getter for value
pub fn get_value(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for automationRate
pub fn get_automationRate(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for defaultValue
pub fn get_defaultValue(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for minValue
pub fn get_minValue(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxValue
pub fn get_maxValue(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for value
pub fn set_value(instance: *runtime.Instance, value: f32) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for automationRate
pub fn set_automationRate(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: setValueAtTime
pub fn call_setValueAtTime(instance: *runtime.Instance, value: f32, startTime: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    _ = startTime;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: linearRampToValueAtTime
pub fn call_linearRampToValueAtTime(instance: *runtime.Instance, value: f32, endTime: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    _ = endTime;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: exponentialRampToValueAtTime
pub fn call_exponentialRampToValueAtTime(instance: *runtime.Instance, value: f32, endTime: f64) ImplError!anyopaque {
    _ = instance;
    _ = value;
    _ = endTime;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setTargetAtTime
pub fn call_setTargetAtTime(instance: *runtime.Instance, target: f32, startTime: f64, timeConstant: f32) ImplError!anyopaque {
    _ = instance;
    _ = target;
    _ = startTime;
    _ = timeConstant;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setValueCurveAtTime
pub fn call_setValueCurveAtTime(instance: *runtime.Instance, values: anyopaque, startTime: f64, duration: f64) ImplError!anyopaque {
    _ = instance;
    _ = values;
    _ = startTime;
    _ = duration;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cancelScheduledValues
pub fn call_cancelScheduledValues(instance: *runtime.Instance, cancelTime: f64) ImplError!anyopaque {
    _ = instance;
    _ = cancelTime;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cancelAndHoldAtTime
pub fn call_cancelAndHoldAtTime(instance: *runtime.Instance, cancelTime: f64) ImplError!anyopaque {
    _ = instance;
    _ = cancelTime;
    // TODO: Implement operation
    return error.NotImplemented;
}

