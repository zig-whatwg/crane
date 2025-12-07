//! WebIDL dictionary: MLQuantizeDequantizeLinearSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLQuantizeDequantizeLinearSupportLimits = struct {
    input: ?MLTensorLimits = null,
    scale: ?MLTensorLimits = null,
    zeroPoint: ?MLTensorLimits = null,
    output: ?MLTensorLimits = null,
};
