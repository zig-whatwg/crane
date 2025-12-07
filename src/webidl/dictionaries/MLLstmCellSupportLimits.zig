//! WebIDL dictionary: MLLstmCellSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLLstmCellSupportLimits = struct {
    input: ?MLTensorLimits = null,
    weight: ?MLTensorLimits = null,
    recurrentWeight: ?MLTensorLimits = null,
    hiddenState: ?MLTensorLimits = null,
    cellState: ?MLTensorLimits = null,
    bias: ?MLTensorLimits = null,
    recurrentBias: ?MLTensorLimits = null,
    peepholeWeight: ?MLTensorLimits = null,
    output0: ?MLTensorLimits = null,
    output1: ?MLTensorLimits = null,
};
