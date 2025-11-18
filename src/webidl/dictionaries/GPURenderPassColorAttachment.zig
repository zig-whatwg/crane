//! WebIDL dictionary: GPURenderPassColorAttachment
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GPURenderPassColorAttachment = struct {
    view: anyopaque,
    depthSlice: ?anyopaque = null,
    resolveTarget: ?anyopaque = null,
    clearValue: ?anyopaque = null,
    loadOp: anyopaque,
    storeOp: anyopaque,
};
