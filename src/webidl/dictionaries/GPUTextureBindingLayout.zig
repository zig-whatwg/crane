//! WebIDL dictionary: GPUTextureBindingLayout
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const GPUTextureBindingLayout = struct {
    sampleType: ?enums.GPUTextureSampleType = null,
    viewDimension: ?enums.GPUTextureViewDimension = null,
    multisampled: ?bool = null,
};
