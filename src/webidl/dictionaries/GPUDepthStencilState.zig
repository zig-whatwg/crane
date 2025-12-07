//! WebIDL dictionary: GPUDepthStencilState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const GPUStencilFaceState = @import("GPUStencilFaceState.zig").GPUStencilFaceState;

pub const GPUDepthStencilState = struct {
    format: enums.GPUTextureFormat,
    depthWriteEnabled: ?bool = null,
    depthCompare: ?enums.GPUCompareFunction = null,
    stencilFront: ?GPUStencilFaceState = null,
    stencilBack: ?GPUStencilFaceState = null,
    stencilReadMask: ?typedefs.GPUStencilValue = null,
    stencilWriteMask: ?typedefs.GPUStencilValue = null,
    depthBias: ?typedefs.GPUDepthBias = null,
    depthBiasSlopeScale: ?f32 = null,
    depthBiasClamp: ?f32 = null,
};
