//! WebIDL dictionary: MLLstmSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLLstmSupportLimits = struct {
    input: ?MLTensorLimits = null,
    weight: ?MLTensorLimits = null,
    recurrentWeight: ?MLTensorLimits = null,
    bias: ?MLTensorLimits = null,
    recurrentBias: ?MLTensorLimits = null,
    peepholeWeight: ?MLTensorLimits = null,
    initialHiddenState: ?MLTensorLimits = null,
    initialCellState: ?MLTensorLimits = null,
    output0: ?MLTensorLimits = null,
    output1: ?MLTensorLimits = null,
    output2: ?MLTensorLimits = null,
};
