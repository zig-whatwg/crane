//! WebIDL dictionary: MLGemmSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLGemmSupportLimits = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    a: ?MLTensorLimits = null,
    b: ?MLTensorLimits = null,
    c: ?MLTensorLimits = null,
    output: ?MLTensorLimits = null,
};
