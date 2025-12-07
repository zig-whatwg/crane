//! WebIDL dictionary: GPUPrimitiveState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const GPUPrimitiveState = struct {
    topology: ?enums.GPUPrimitiveTopology = null,
    stripIndexFormat: ?enums.GPUIndexFormat = null,
    frontFace: ?enums.GPUFrontFace = null,
    cullMode: ?enums.GPUCullMode = null,
    unclippedDepth: ?bool = null,
};
