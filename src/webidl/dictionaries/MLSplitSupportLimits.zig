//! WebIDL dictionary: MLSplitSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLSplitSupportLimits = struct {
    input: ?MLTensorLimits = null,
    outputs: ?MLTensorLimits = null,
};
