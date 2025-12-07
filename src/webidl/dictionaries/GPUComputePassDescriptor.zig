//! WebIDL dictionary: GPUComputePassDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const GPUComputePassTimestampWrites = @import("GPUComputePassTimestampWrites.zig").GPUComputePassTimestampWrites;
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUComputePassDescriptor = struct {
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    timestampWrites: ?GPUComputePassTimestampWrites = null,
};
