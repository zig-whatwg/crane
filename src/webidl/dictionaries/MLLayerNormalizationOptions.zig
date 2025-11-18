//! WebIDL dictionary: MLLayerNormalizationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLLayerNormalizationOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    scale: ?anyopaque = null,
    bias: ?anyopaque = null,
    axes: ?anyopaque = null,
    epsilon: ?f64 = null,
};
