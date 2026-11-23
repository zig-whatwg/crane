//! WebIDL dictionary: GPUPipelineDescriptorBase
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUPipelineDescriptorBase = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    layout: typedefs.GPUPipelineLayoutOrGPUAutoLayoutMode,
};
