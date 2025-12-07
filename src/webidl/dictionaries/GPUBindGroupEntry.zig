//! WebIDL dictionary: GPUBindGroupEntry
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const GPUBindGroupEntry = struct {
    binding: typedefs.GPUIndex32,
    resource: typedefs.GPUBindingResource,
};
