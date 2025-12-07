//! WebIDL dictionary: GPUComputePipelineDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUProgrammableStage = @import("GPUProgrammableStage.zig").GPUProgrammableStage;
const GPUPipelineDescriptorBase = @import("GPUPipelineDescriptorBase.zig").GPUPipelineDescriptorBase;

pub const GPUComputePipelineDescriptor = struct {
    // Inherited from GPUPipelineDescriptorBase
    base: GPUPipelineDescriptorBase,

    compute: GPUProgrammableStage,
};
