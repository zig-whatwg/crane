//! WebIDL dictionary: GPUStorageTextureBindingLayout
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const GPUStorageTextureBindingLayout = struct {
    access: ?enums.GPUStorageTextureAccess = null,
    format: enums.GPUTextureFormat,
    viewDimension: ?enums.GPUTextureViewDimension = null,
};
