//! Implementation for GPUQueue interface
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
const GPUQueue = interfaces.GPUQueue;

pub const State = GPUQueue.State;

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

/// Getter for label
pub fn get_label(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for label
pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: onSubmittedWorkDone
pub fn call_onSubmittedWorkDone(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: writeBuffer
pub fn call_writeBuffer(instance: *runtime.Instance, buffer: interfaces.GPUBuffer, bufferOffset: typedefs.GPUSize64, data: typedefs.AllowSharedBufferSource, dataOffset: typedefs.GPUSize64, size: typedefs.GPUSize64) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = bufferOffset;
    _ = data;
    _ = dataOffset;
    _ = size;
    return error.NotImplemented;
}

/// Operation: writeTexture
pub fn call_writeTexture(instance: *runtime.Instance, destination: dictionaries.GPUTexelCopyTextureInfo, data: typedefs.AllowSharedBufferSource, dataLayout: dictionaries.GPUTexelCopyBufferLayout, size: typedefs.GPUExtent3D) ImplError!void {
    _ = instance;
    _ = destination;
    _ = data;
    _ = dataLayout;
    _ = size;
    return error.NotImplemented;
}

/// Operation: submit
pub fn call_submit(instance: *runtime.Instance, commandBuffers: *const anyopaque) ImplError!void {
    _ = instance;
    _ = commandBuffers;
    return error.NotImplemented;
}

/// Operation: copyExternalImageToTexture
pub fn call_copyExternalImageToTexture(instance: *runtime.Instance, source: dictionaries.GPUCopyExternalImageSourceInfo, destination: dictionaries.GPUCopyExternalImageDestInfo, copySize: typedefs.GPUExtent3D) ImplError!void {
    _ = instance;
    _ = source;
    _ = destination;
    _ = copySize;
    return error.NotImplemented;
}

