//! WebIDL dictionary: GPURenderPassDepthStencilAttachment
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GPURenderPassDepthStencilAttachment = struct {
    view: *const anyopaque,
    depthClearValue: ?f32 = null,
    depthLoadOp: ?*const anyopaque = null,
    depthStoreOp: ?*const anyopaque = null,
    depthReadOnly: ?bool = null,
    stencilClearValue: ?*const anyopaque = null,
    stencilLoadOp: ?*const anyopaque = null,
    stencilStoreOp: ?*const anyopaque = null,
    stencilReadOnly: ?bool = null,
};
