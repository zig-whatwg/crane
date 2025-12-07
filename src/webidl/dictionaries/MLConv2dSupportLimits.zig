//! WebIDL dictionary: MLConv2dSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLConv2dSupportLimits = struct {
    input: ?MLTensorLimits = null,
    filter: ?MLTensorLimits = null,
    bias: ?MLTensorLimits = null,
    output: ?MLTensorLimits = null,
};
