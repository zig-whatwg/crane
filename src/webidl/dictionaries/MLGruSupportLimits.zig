//! WebIDL dictionary: MLGruSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLGruSupportLimits = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    input: ?MLTensorLimits = null,
    weight: ?MLTensorLimits = null,
    recurrentWeight: ?MLTensorLimits = null,
    bias: ?MLTensorLimits = null,
    recurrentBias: ?MLTensorLimits = null,
    initialHiddenState: ?MLTensorLimits = null,
    output0: ?MLTensorLimits = null,
    output1: ?MLTensorLimits = null,
};
