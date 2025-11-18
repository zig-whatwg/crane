//! Implementation for AudioWorkletGlobalScope interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const AudioWorkletGlobalScope = @import("interfaces").AudioWorkletGlobalScope;

pub const State = AudioWorkletGlobalScope.State;

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

/// Getter for currentFrame
pub fn get_currentFrame(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for currentTime
pub fn get_currentTime(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for sampleRate
pub fn get_sampleRate(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for renderQuantumSize
pub fn get_renderQuantumSize(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for port
pub fn get_port(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: registerProcessor
pub fn call_registerProcessor(instance: *runtime.Instance, name: runtime.DOMString, processorCtor: anyopaque) ImplError!void {
    _ = instance;
    _ = name;
    _ = processorCtor;
    // TODO: Implement operation
    return error.NotImplemented;
}

