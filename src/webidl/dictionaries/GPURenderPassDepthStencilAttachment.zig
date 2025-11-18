//! WebIDL dictionary: GPURenderPassDepthStencilAttachment
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GPURenderPassDepthStencilAttachment = struct {
    view: anyopaque,
    depthClearValue: ?f32 = null,
    depthLoadOp: ?anyopaque = null,
    depthStoreOp: ?anyopaque = null,
    depthReadOnly: ?bool = null,
    stencilClearValue: ?anyopaque = null,
    stencilLoadOp: ?anyopaque = null,
    stencilStoreOp: ?anyopaque = null,
    stencilReadOnly: ?bool = null,
};
