//! Implementation for MLContext interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const MLContext = interfaces.MLContext;

pub const State = MLContext.State;

pub const ImplError = error{
    NotImplemented,
};

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

/// Getter for accelerated
pub fn get_accelerated(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lost
pub fn get_lost(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: dispatch
pub fn call_dispatch(instance: *runtime.Instance, graph: *runtime.Instance, inputs: typedefs.MLNamedTensors, outputs: typedefs.MLNamedTensors) ImplError!void {
    _ = instance;
    _ = graph;
    _ = inputs;
    _ = outputs;
    return error.NotImplemented;
}

/// Operation: opSupportLimits
pub fn call_opSupportLimits(instance: *runtime.Instance) ImplError!dictionaries.MLOpSupportLimits {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: writeTensor
pub fn call_writeTensor(instance: *runtime.Instance, tensor: *runtime.Instance, inputData: typedefs.AllowSharedBufferSource) ImplError!void {
    _ = instance;
    _ = tensor;
    _ = inputData;
    return error.NotImplemented;
}

/// Operation: readTensor
pub fn call_readTensor(instance: *runtime.Instance, tensor: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    _ = tensor;
    return error.NotImplemented;
}

/// Operation: createTensor
pub fn call_createTensor(instance: *runtime.Instance, descriptor: dictionaries.MLTensorDescriptor) ImplError!*const anyopaque {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: destroy
pub fn call_destroy(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createConstantTensor
pub fn call_createConstantTensor(instance: *runtime.Instance, descriptor: dictionaries.MLOperandDescriptor, inputData: typedefs.AllowSharedBufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = descriptor;
    _ = inputData;
    return error.NotImplemented;
}

