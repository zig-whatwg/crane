//! WebIDL dictionary: MLSingleInputSupportLimits
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLTensorLimits = @import("MLTensorLimits.zig").MLTensorLimits;

pub const MLSingleInputSupportLimits = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    input: ?MLTensorLimits = null,
    output: ?MLTensorLimits = null,
};
