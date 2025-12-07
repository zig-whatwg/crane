//! WebIDL dictionary: MLWhereSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLWhereSupportLimits = struct {
    condition: ?MLTensorLimits = null,
    trueValue: ?MLTensorLimits = null,
    falseValue: ?MLTensorLimits = null,
    output: ?MLTensorLimits = null,
};
