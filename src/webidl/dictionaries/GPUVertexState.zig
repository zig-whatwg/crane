//! WebIDL dictionary: GPUVertexState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUProgrammableStage = @import("GPUProgrammableStage.zig").GPUProgrammableStage;

pub const GPUVertexState = struct {
    // Inherited from GPUProgrammableStage
    base: GPUProgrammableStage,

    buffers: ?anyopaque = null,
};
