//! WebIDL dictionary: GPUVertexBufferLayout
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const GPUVertexAttribute = @import("GPUVertexAttribute.zig").GPUVertexAttribute;

pub const GPUVertexBufferLayout = struct {
    arrayStride: typedefs.GPUSize64,
    stepMode: ?enums.GPUVertexStepMode = null,
    attributes: []const GPUVertexAttribute,
};
