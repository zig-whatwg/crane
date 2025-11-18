//! Implementation for AudioBufferSourceNode interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const AudioBufferSourceNode = @import("interfaces").AudioBufferSourceNode;

pub const State = AudioBufferSourceNode.State;

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

/// Getter for onended
pub fn get_onended(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for buffer
pub fn get_buffer(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for playbackRate
pub fn get_playbackRate(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for detune
pub fn get_detune(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for loop
pub fn get_loop(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for loopStart
pub fn get_loopStart(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for loopEnd
pub fn get_loopEnd(instance: *runtime.Instance) ImplError!f64 {
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

/// Setter for onended
pub fn set_onended(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for buffer
pub fn set_buffer(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for loop
pub fn set_loop(instance: *runtime.Instance, value: bool) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for loopStart
pub fn set_loopStart(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for loopEnd
pub fn set_loopEnd(instance: *runtime.Instance, value: f64) ImplError!void {
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

/// Operation: start
pub fn call_start(instance: *runtime.Instance, when: f64) ImplError!void {
    _ = instance;
    _ = when;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: stop
pub fn call_stop(instance: *runtime.Instance, when: f64) ImplError!void {
    _ = instance;
    _ = when;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: start
pub fn call_start(instance: *runtime.Instance, when: f64, offset: f64, duration: f64) ImplError!void {
    _ = instance;
    _ = when;
    _ = offset;
    _ = duration;
    // TODO: Implement operation
    return error.NotImplemented;
}

