//! WebIDL dictionary: MLSingleInputSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLSingleInputSupportLimits = struct {
    input: ?MLTensorLimits = null,
    output: ?MLTensorLimits = null,
};
