//! Implementation for GPUComputePassEncoder interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const GPUComputePassEncoder = @import("interfaces").GPUComputePassEncoder;

pub const State = GPUComputePassEncoder.State;

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

/// Operation: setPipeline
pub fn call_setPipeline(instance: *runtime.Instance, pipeline: anyopaque) ImplError!void {
    _ = instance;
    _ = pipeline;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dispatchWorkgroups
pub fn call_dispatchWorkgroups(instance: *runtime.Instance, workgroupCountX: anyopaque, workgroupCountY: anyopaque, workgroupCountZ: anyopaque) ImplError!void {
    _ = instance;
    _ = workgroupCountX;
    _ = workgroupCountY;
    _ = workgroupCountZ;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dispatchWorkgroupsIndirect
pub fn call_dispatchWorkgroupsIndirect(instance: *runtime.Instance, indirectBuffer: anyopaque, indirectOffset: anyopaque) ImplError!void {
    _ = instance;
    _ = indirectBuffer;
    _ = indirectOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: end
pub fn call_end(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: pushDebugGroup
pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = groupLabel;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: popDebugGroup
pub fn call_popDebugGroup(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: insertDebugMarker
pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = markerLabel;
    // TODO: Implement operation
    return error.NotImplemented;
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

