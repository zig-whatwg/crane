//! WebIDL dictionary: MLBinarySupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLBinarySupportLimits = struct {
    a: ?MLTensorLimits = null,
    b: ?MLTensorLimits = null,
    output: ?MLTensorLimits = null,
};
