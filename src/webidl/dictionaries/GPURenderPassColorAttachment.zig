//! WebIDL dictionary: GPURenderPassColorAttachment
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const GPURenderPassColorAttachment = struct {
    view: runtime.JSValue,
    depthSlice: ?typedefs.GPUIntegerCoordinate = null,
    resolveTarget: ?runtime.JSValue = null,
    clearValue: ?typedefs.GPUColor = null,
    loadOp: enums.GPULoadOp,
    storeOp: enums.GPUStoreOp,
};
