//! WebIDL dictionary: GPUDepthStencilState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GPUDepthStencilState = struct {
    format: *const anyopaque,
    depthWriteEnabled: ?bool = null,
    depthCompare: ?*const anyopaque = null,
    stencilFront: ?*const anyopaque = null,
    stencilBack: ?*const anyopaque = null,
    stencilReadMask: ?*const anyopaque = null,
    stencilWriteMask: ?*const anyopaque = null,
    depthBias: ?*const anyopaque = null,
    depthBiasSlopeScale: ?f32 = null,
    depthBiasClamp: ?f32 = null,
};
