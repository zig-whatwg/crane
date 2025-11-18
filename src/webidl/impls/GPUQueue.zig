//! Implementation for GPUQueue interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const GPUQueue = @import("interfaces").GPUQueue;

pub const State = GPUQueue.State;

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

/// Getter for label
pub fn get_label(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for label
pub fn set_label(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: submit
pub fn call_submit(instance: *runtime.Instance, commandBuffers: anyopaque) ImplError!void {
    _ = instance;
    _ = commandBuffers;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: onSubmittedWorkDone
pub fn call_onSubmittedWorkDone(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: writeBuffer
pub fn call_writeBuffer(instance: *runtime.Instance, buffer: anyopaque, bufferOffset: anyopaque, data: anyopaque, dataOffset: anyopaque, size: anyopaque) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = bufferOffset;
    _ = data;
    _ = dataOffset;
    _ = size;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: writeTexture
pub fn call_writeTexture(instance: *runtime.Instance, destination: anyopaque, data: anyopaque, dataLayout: anyopaque, size: anyopaque) ImplError!void {
    _ = instance;
    _ = destination;
    _ = data;
    _ = dataLayout;
    _ = size;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: copyExternalImageToTexture
pub fn call_copyExternalImageToTexture(instance: *runtime.Instance, source: anyopaque, destination: anyopaque, copySize: anyopaque) ImplError!void {
    _ = instance;
    _ = source;
    _ = destination;
    _ = copySize;
    // TODO: Implement operation
    return error.NotImplemented;
}

