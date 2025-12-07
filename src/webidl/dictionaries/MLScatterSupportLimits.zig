//! WebIDL dictionary: MLScatterSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLScatterSupportLimits = struct {
    input: ?MLTensorLimits = null,
    indices: ?MLTensorLimits = null,
    updates: ?MLTensorLimits = null,
    output: ?MLTensorLimits = null,
};
