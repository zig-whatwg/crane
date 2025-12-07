//! WebIDL dictionary: MLGatherSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLGatherSupportLimits = struct {
    input: ?MLTensorLimits = null,
    indices: ?MLTensorLimits = null,
    output: ?MLTensorLimits = null,
};
