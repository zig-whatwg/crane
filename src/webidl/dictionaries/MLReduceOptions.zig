//! WebIDL dictionary: MLReduceOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLReduceOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    axes: ?anyopaque = null,
    keepDimensions: ?bool = null,
};
