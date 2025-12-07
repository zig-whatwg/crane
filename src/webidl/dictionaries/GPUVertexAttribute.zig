//! WebIDL dictionary: GPUVertexAttribute
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const GPUVertexAttribute = struct {
    format: enums.GPUVertexFormat,
    offset: typedefs.GPUSize64,
    shaderLocation: typedefs.GPUIndex32,
};
