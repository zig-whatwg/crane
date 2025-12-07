//! WebIDL dictionary: MLGruCellSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLGruCellSupportLimits = struct {
    input: ?MLTensorLimits = null,
    weight: ?MLTensorLimits = null,
    recurrentWeight: ?MLTensorLimits = null,
    hiddenState: ?MLTensorLimits = null,
    bias: ?MLTensorLimits = null,
    recurrentBias: ?MLTensorLimits = null,
    output: ?MLTensorLimits = null,
};
