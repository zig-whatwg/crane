//! WebIDL dictionary: MLBinarySupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLBinarySupportLimits = struct {
    a: ?MLTensorLimits = null,
    b: ?MLTensorLimits = null,
    output: ?MLTensorLimits = null,
};
