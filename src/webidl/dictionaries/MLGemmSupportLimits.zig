//! WebIDL dictionary: MLGemmSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLGemmSupportLimits = struct {
    a: ?MLTensorLimits = null,
    b: ?MLTensorLimits = null,
    c: ?MLTensorLimits = null,
    output: ?MLTensorLimits = null,
};
