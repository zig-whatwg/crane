//! WebIDL dictionary: MLBatchNormalizationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLBatchNormalizationOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    scale: ?anyopaque = null,
    bias: ?anyopaque = null,
    axis: ?u32 = null,
    epsilon: ?f64 = null,
};
