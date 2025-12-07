//! WebIDL dictionary: MLPreluSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLPreluSupportLimits = struct {
    input: ?MLTensorLimits = null,
    slope: ?MLTensorLimits = null,
    output: ?MLTensorLimits = null,
};
