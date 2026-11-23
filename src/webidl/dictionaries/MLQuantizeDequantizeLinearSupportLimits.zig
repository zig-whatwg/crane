//! WebIDL dictionary: MLQuantizeDequantizeLinearSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLQuantizeDequantizeLinearSupportLimits = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    input: ?MLTensorLimits = null,
    scale: ?MLTensorLimits = null,
    zeroPoint: ?MLTensorLimits = null,
    output: ?MLTensorLimits = null,
};
