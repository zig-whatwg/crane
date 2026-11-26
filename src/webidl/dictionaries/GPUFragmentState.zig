//! WebIDL dictionary: GPUFragmentState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPUColorTargetState = @import("GPUColorTargetState.zig").GPUColorTargetState;
const GPUProgrammableStage = @import("GPUProgrammableStage.zig").GPUProgrammableStage;

pub const GPUFragmentState = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from GPUProgrammableStage
    base: GPUProgrammableStage,

    targets: []const ?GPUColorTargetState,
};
