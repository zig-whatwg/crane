//! Implementation for GPUComputePassEncoder interface
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
const GPUComputePassEncoder = interfaces.GPUComputePassEncoder;

pub const State = GPUComputePassEncoder.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for this implementation
/// Can be used to store browser-specific data structures
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

/// Operation: dispatchWorkgroups
pub fn call_dispatchWorkgroups(instance: *runtime.Instance, workgroupCountX: typedefs.GPUSize32, workgroupCountY: typedefs.GPUSize32, workgroupCountZ: typedefs.GPUSize32) ImplError!void {
    _ = instance;
    _ = workgroupCountX;
    _ = workgroupCountY;
    _ = workgroupCountZ;
    return error.NotImplemented;
}

/// Operation: popDebugGroup
pub fn call_popDebugGroup(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setBindGroup
pub fn call_setBindGroup(instance: *runtime.Instance, index: typedefs.GPUIndex32, bindGroup: interfaces.GPUBindGroup, dynamicOffsets: *const anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = bindGroup;
    _ = dynamicOffsets;
    return error.NotImplemented;
}

/// Operation: dispatchWorkgroupsIndirect
pub fn call_dispatchWorkgroupsIndirect(instance: *runtime.Instance, indirectBuffer: interfaces.GPUBuffer, indirectOffset: typedefs.GPUSize64) ImplError!void {
    _ = instance;
    _ = indirectBuffer;
    _ = indirectOffset;
    return error.NotImplemented;
}

/// Operation: insertDebugMarker
pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.USVString) ImplError!void {
    _ = instance;
    _ = markerLabel;
    return error.NotImplemented;
}

/// Operation: pushDebugGroup
pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.USVString) ImplError!void {
    _ = instance;
    _ = groupLabel;
    return error.NotImplemented;
}

/// Operation: end
pub fn call_end(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setPipeline
pub fn call_setPipeline(instance: *runtime.Instance, pipeline: interfaces.GPUComputePipeline) ImplError!void {
    _ = instance;
    _ = pipeline;
    return error.NotImplemented;
}

