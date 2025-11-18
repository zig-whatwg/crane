//! Implementation for GPUBindingCommandsMixin interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const GPUBindingCommandsMixin = @import("interfaces").GPUBindingCommandsMixin;

pub const State = GPUBindingCommandsMixin.State;

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

/// Operation: setBindGroup
pub fn call_setBindGroup(instance: *runtime.Instance, index: anyopaque, bindGroup: anyopaque, dynamicOffsets: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = bindGroup;
    _ = dynamicOffsets;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setBindGroup
pub fn call_setBindGroup(instance: *runtime.Instance, index: anyopaque, bindGroup: anyopaque, dynamicOffsetsData: anyopaque, dynamicOffsetsDataStart: anyopaque, dynamicOffsetsDataLength: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = bindGroup;
    _ = dynamicOffsetsData;
    _ = dynamicOffsetsDataStart;
    _ = dynamicOffsetsDataLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

