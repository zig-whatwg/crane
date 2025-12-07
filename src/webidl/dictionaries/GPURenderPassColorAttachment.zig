//! WebIDL dictionary: GPURenderPassColorAttachment
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const GPURenderPassColorAttachment = struct {
    view: *const anyopaque,
    depthSlice: ?typedefs.GPUIntegerCoordinate = null,
    resolveTarget: ?*const anyopaque = null,
    clearValue: ?typedefs.GPUColor = null,
    loadOp: enums.GPULoadOp,
    storeOp: enums.GPUStoreOp,
};
