//! WebIDL dictionary: MLSplitOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLSplitOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    axis: ?u32 = null,
};
