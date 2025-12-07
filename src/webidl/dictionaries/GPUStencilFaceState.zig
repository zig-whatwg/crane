//! WebIDL dictionary: GPUStencilFaceState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const GPUStencilFaceState = struct {
    compare: ?enums.GPUCompareFunction = null,
    failOp: ?enums.GPUStencilOperation = null,
    depthFailOp: ?enums.GPUStencilOperation = null,
    passOp: ?enums.GPUStencilOperation = null,
};
