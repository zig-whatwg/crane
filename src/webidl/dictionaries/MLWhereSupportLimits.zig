//! WebIDL dictionary: MLWhereSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLWhereSupportLimits = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    condition: ?MLTensorLimits = null,
    trueValue: ?MLTensorLimits = null,
    falseValue: ?MLTensorLimits = null,
    output: ?MLTensorLimits = null,
};
