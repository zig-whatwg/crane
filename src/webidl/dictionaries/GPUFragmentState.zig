//! WebIDL dictionary: GPUFragmentState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUProgrammableStage = @import("GPUProgrammableStage.zig").GPUProgrammableStage;

pub const GPUFragmentState = struct {
    // Inherited from GPUProgrammableStage
    base: GPUProgrammableStage,

    targets: anyopaque,
};
