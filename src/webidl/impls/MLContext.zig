//! Implementation for MLContext interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const MLContext = @import("interfaces").MLContext;

pub const State = MLContext.State;

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

/// Getter for lost
pub fn get_lost(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: dispatch
pub fn call_dispatch(instance: *runtime.Instance, graph: anyopaque, inputs: anyopaque, outputs: anyopaque) ImplError!void {
    _ = instance;
    _ = graph;
    _ = inputs;
    _ = outputs;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createTensor
pub fn call_createTensor(instance: *runtime.Instance, descriptor: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = descriptor;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createConstantTensor
pub fn call_createConstantTensor(instance: *runtime.Instance, descriptor: anyopaque, inputData: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = descriptor;
    _ = inputData;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: readTensor
pub fn call_readTensor(instance: *runtime.Instance, tensor: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = tensor;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: readTensor
pub fn call_readTensor(instance: *runtime.Instance, tensor: anyopaque, outputData: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = tensor;
    _ = outputData;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: writeTensor
pub fn call_writeTensor(instance: *runtime.Instance, tensor: anyopaque, inputData: anyopaque) ImplError!void {
    _ = instance;
    _ = tensor;
    _ = inputData;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: opSupportLimits
pub fn call_opSupportLimits(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: destroy
pub fn call_destroy(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

