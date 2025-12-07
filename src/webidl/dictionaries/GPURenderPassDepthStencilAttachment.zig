//! WebIDL dictionary: GPURenderPassDepthStencilAttachment
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const GPURenderPassDepthStencilAttachment = struct {
    view: *const anyopaque,
    depthClearValue: ?f32 = null,
    depthLoadOp: ?enums.GPULoadOp = null,
    depthStoreOp: ?enums.GPUStoreOp = null,
    depthReadOnly: ?bool = null,
    stencilClearValue: ?typedefs.GPUStencilValue = null,
    stencilLoadOp: ?enums.GPULoadOp = null,
    stencilStoreOp: ?enums.GPUStoreOp = null,
    stencilReadOnly: ?bool = null,
};
