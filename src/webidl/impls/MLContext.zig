//! Implementation for MLContext interface

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
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for accelerated
pub fn get_accelerated(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lost
pub fn get_lost(instance: *runtime.Instance) anyerror!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: dispatch
pub fn call_dispatch(instance: *runtime.Instance, graph: *runtime.Instance, inputs: typedefs.MLNamedTensors, outputs: typedefs.MLNamedTensors) anyerror!void {
    _ = instance;
    _ = graph;
    _ = inputs;
    _ = outputs;
    return error.NotImplemented;
}

/// Operation: opSupportLimits
pub fn call_opSupportLimits(instance: *runtime.Instance) anyerror!dictionaries.MLOpSupportLimits {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: writeTensor
pub fn call_writeTensor(instance: *runtime.Instance, tensor: *runtime.Instance, inputData: typedefs.AllowSharedBufferSource) anyerror!void {
    _ = instance;
    _ = tensor;
    _ = inputData;
    return error.NotImplemented;
}

/// Operation: readTensor
pub fn call_readTensor(instance: *runtime.Instance, tensor: *runtime.Instance) anyerror!*const anyopaque {
    _ = instance;
    _ = tensor;
    return error.NotImplemented;
}

/// Operation: createTensor
pub fn call_createTensor(instance: *runtime.Instance, descriptor: dictionaries.MLTensorDescriptor) anyerror!*const anyopaque {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: destroy
pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createConstantTensor
pub fn call_createConstantTensor(instance: *runtime.Instance, descriptor: dictionaries.MLOperandDescriptor, inputData: typedefs.AllowSharedBufferSource) anyerror!*const anyopaque {
    _ = instance;
    _ = descriptor;
    _ = inputData;
    return error.NotImplemented;
}
