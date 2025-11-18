//! Implementation for AnalyserNode interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const AnalyserNode = @import("interfaces").AnalyserNode;

pub const State = AnalyserNode.State;

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

/// Constructor implementation
pub fn constructor(instance: *runtime.Instance) !void {
    _ = instance;
    // TODO: Implement constructor logic
}

/// Getter for context
pub fn get_context(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for numberOfInputs
pub fn get_numberOfInputs(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for numberOfOutputs
pub fn get_numberOfOutputs(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for channelCount
pub fn get_channelCount(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for channelCountMode
pub fn get_channelCountMode(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for channelInterpretation
pub fn get_channelInterpretation(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for fftSize
pub fn get_fftSize(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for frequencyBinCount
pub fn get_frequencyBinCount(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for minDecibels
pub fn get_minDecibels(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxDecibels
pub fn get_maxDecibels(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for smoothingTimeConstant
pub fn get_smoothingTimeConstant(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for channelCount
pub fn set_channelCount(instance: *runtime.Instance, value: u32) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for channelCountMode
pub fn set_channelCountMode(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for channelInterpretation
pub fn set_channelInterpretation(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for fftSize
pub fn set_fftSize(instance: *runtime.Instance, value: u32) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for minDecibels
pub fn set_minDecibels(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for maxDecibels
pub fn set_maxDecibels(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for smoothingTimeConstant
pub fn set_smoothingTimeConstant(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: addEventListener
pub fn call_addEventListener(instance: *runtime.Instance, type: runtime.DOMString, callback: anyopaque, options: anyopaque) ImplError!void {
    _ = instance;
    _ = type;
    _ = callback;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeEventListener
pub fn call_removeEventListener(instance: *runtime.Instance, type: runtime.DOMString, callback: anyopaque, options: anyopaque) ImplError!void {
    _ = instance;
    _ = type;
    _ = callback;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dispatchEvent
pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) ImplError!bool {
    _ = instance;
    _ = event;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: when
pub fn call_when(instance: *runtime.Instance, type: runtime.DOMString, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = type;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: connect
pub fn call_connect(instance: *runtime.Instance, destinationNode: anyopaque, output: u32, input: u32) ImplError!anyopaque {
    _ = instance;
    _ = destinationNode;
    _ = output;
    _ = input;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: connect
pub fn call_connect(instance: *runtime.Instance, destinationParam: anyopaque, output: u32) ImplError!void {
    _ = instance;
    _ = destinationParam;
    _ = output;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: disconnect
pub fn call_disconnect(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: disconnect
pub fn call_disconnect(instance: *runtime.Instance, output: u32) ImplError!void {
    _ = instance;
    _ = output;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: disconnect
pub fn call_disconnect(instance: *runtime.Instance, destinationNode: anyopaque) ImplError!void {
    _ = instance;
    _ = destinationNode;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: disconnect
pub fn call_disconnect(instance: *runtime.Instance, destinationNode: anyopaque, output: u32) ImplError!void {
    _ = instance;
    _ = destinationNode;
    _ = output;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: disconnect
pub fn call_disconnect(instance: *runtime.Instance, destinationNode: anyopaque, output: u32, input: u32) ImplError!void {
    _ = instance;
    _ = destinationNode;
    _ = output;
    _ = input;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: disconnect
pub fn call_disconnect(instance: *runtime.Instance, destinationParam: anyopaque) ImplError!void {
    _ = instance;
    _ = destinationParam;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: disconnect
pub fn call_disconnect(instance: *runtime.Instance, destinationParam: anyopaque, output: u32) ImplError!void {
    _ = instance;
    _ = destinationParam;
    _ = output;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getFloatFrequencyData
pub fn call_getFloatFrequencyData(instance: *runtime.Instance, array: anyopaque) ImplError!void {
    _ = instance;
    _ = array;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getByteFrequencyData
pub fn call_getByteFrequencyData(instance: *runtime.Instance, array: anyopaque) ImplError!void {
    _ = instance;
    _ = array;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getFloatTimeDomainData
pub fn call_getFloatTimeDomainData(instance: *runtime.Instance, array: anyopaque) ImplError!void {
    _ = instance;
    _ = array;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getByteTimeDomainData
pub fn call_getByteTimeDomainData(instance: *runtime.Instance, array: anyopaque) ImplError!void {
    _ = instance;
    _ = array;
    // TODO: Implement operation
    return error.NotImplemented;
}

