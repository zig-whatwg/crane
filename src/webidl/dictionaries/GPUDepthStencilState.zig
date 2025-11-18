//! WebIDL dictionary: GPUDepthStencilState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GPUDepthStencilState = struct {
    format: anyopaque,
    depthWriteEnabled: ?bool = null,
    depthCompare: ?anyopaque = null,
    stencilFront: ?anyopaque = null,
    stencilBack: ?anyopaque = null,
    stencilReadMask: ?anyopaque = null,
    stencilWriteMask: ?anyopaque = null,
    depthBias: ?anyopaque = null,
    depthBiasSlopeScale: ?f32 = null,
    depthBiasClamp: ?f32 = null,
};
