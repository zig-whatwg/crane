//! WebIDL dictionary: MLConcatSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLConcatSupportLimits = struct {
    inputs: ?MLTensorLimits = null,
    output: ?MLTensorLimits = null,
};
