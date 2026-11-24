//! WebIDL dictionary: GPURenderPassColorAttachment
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const GPURenderPassColorAttachment = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    view: typedefs.GPUTextureOrGPUTextureView,
    depthSlice: ?typedefs.GPUIntegerCoordinate = null,
    resolveTarget: ?typedefs.GPUTextureOrGPUTextureView = null,
    clearValue: ?typedefs.GPUColor = null,
    loadOp: enums.GPULoadOp,
    storeOp: enums.GPUStoreOp,
};
