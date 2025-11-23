//! WebIDL dictionary: GPURenderPassColorAttachment
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GPURenderPassColorAttachment = struct {
    view: *const anyopaque,
    depthSlice: ?*const anyopaque = null,
    resolveTarget: ?*const anyopaque = null,
    clearValue: ?*const anyopaque = null,
    loadOp: *const anyopaque,
    storeOp: *const anyopaque,
};
