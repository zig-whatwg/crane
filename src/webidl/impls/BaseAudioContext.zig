//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for BaseAudioContext interface
//!
//! This file is AUTO-GENERATED into impls_tmp/ directory.
//! The impls_tmp/ directory is gitignored and NOT part of the build.
//!
//! TO USE THIS STUB:
//!   1. Copy this file to src/webidl/impls/
//!   2. Add your implementation logic
//!   3. The impls/ directory is the canonical location for implementations
//!
//! If updating an existing implementation:
//!   1. Diff this stub against the existing file in impls/
//!   2. Manually merge new signatures while preserving custom code
//!
//! ============================================================================

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const BaseAudioContext = interfaces.BaseAudioContext;

pub const State = BaseAudioContext.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Getter for destination
pub fn get_destination(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sampleRate
pub fn get_sampleRate(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for currentTime
pub fn get_currentTime(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for listener
pub fn get_listener(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for state
pub fn get_state(instance: *runtime.Instance) ImplError!enums.AudioContextState {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for renderQuantumSize
pub fn get_renderQuantumSize(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for audioWorklet
pub fn get_audioWorklet(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onstatechange
pub fn get_onstatechange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onstatechange
pub fn set_onstatechange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: createPanner
pub fn call_createPanner(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createChannelMerger
pub fn call_createChannelMerger(instance: *runtime.Instance, numberOfInputs: u32) ImplError!*runtime.Instance {
    _ = instance;
    _ = numberOfInputs;
    return error.NotImplemented;
}

/// Operation: createDynamicsCompressor
pub fn call_createDynamicsCompressor(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createPeriodicWave
pub fn call_createPeriodicWave(instance: *runtime.Instance, real: *const anyopaque, imag: *const anyopaque, constraints: dictionaries.PeriodicWaveConstraints) ImplError!*runtime.Instance {
    _ = instance;
    _ = real;
    _ = imag;
    _ = constraints;
    return error.NotImplemented;
}

/// Operation: createConvolver
pub fn call_createConvolver(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createBufferSource
pub fn call_createBufferSource(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createStereoPanner
pub fn call_createStereoPanner(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createGain
pub fn call_createGain(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createWaveShaper
pub fn call_createWaveShaper(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createConstantSource
pub fn call_createConstantSource(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createAnalyser
pub fn call_createAnalyser(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createIIRFilter
pub fn call_createIIRFilter(instance: *runtime.Instance, feedforward: *const anyopaque, feedback: *const anyopaque) ImplError!*runtime.Instance {
    _ = instance;
    _ = feedforward;
    _ = feedback;
    return error.NotImplemented;
}

/// Operation: createBiquadFilter
pub fn call_createBiquadFilter(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createOscillator
pub fn call_createOscillator(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createBuffer
pub fn call_createBuffer(instance: *runtime.Instance, numberOfChannels: u32, length: u32, sampleRate: f32) ImplError!*runtime.Instance {
    _ = instance;
    _ = numberOfChannels;
    _ = length;
    _ = sampleRate;
    return error.NotImplemented;
}

/// Operation: createScriptProcessor
pub fn call_createScriptProcessor(instance: *runtime.Instance, bufferSize: u32, numberOfInputChannels: u32, numberOfOutputChannels: u32) ImplError!*runtime.Instance {
    _ = instance;
    _ = bufferSize;
    _ = numberOfInputChannels;
    _ = numberOfOutputChannels;
    return error.NotImplemented;
}

/// Operation: createDelay
pub fn call_createDelay(instance: *runtime.Instance, maxDelayTime: f64) ImplError!*runtime.Instance {
    _ = instance;
    _ = maxDelayTime;
    return error.NotImplemented;
}

/// Operation: createChannelSplitter
pub fn call_createChannelSplitter(instance: *runtime.Instance, numberOfOutputs: u32) ImplError!*runtime.Instance {
    _ = instance;
    _ = numberOfOutputs;
    return error.NotImplemented;
}

/// Operation: decodeAudioData
pub fn call_decodeAudioData(instance: *runtime.Instance, audioData: *const anyopaque, successCallback: callbacks.DecodeSuccessCallback, errorCallback: callbacks.DecodeErrorCallback) ImplError!*const anyopaque {
    _ = instance;
    _ = audioData;
    _ = successCallback;
    _ = errorCallback;
    return error.NotImplemented;
}

