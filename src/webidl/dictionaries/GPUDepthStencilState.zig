//! WebIDL dictionary: GPUDepthStencilState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
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

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "depthBiasSlopeScale", "depthBiasClamp" };
};
