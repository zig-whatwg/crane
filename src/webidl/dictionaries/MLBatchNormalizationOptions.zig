//! WebIDL dictionary: MLBatchNormalizationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLBatchNormalizationOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    scale: ?*runtime.Instance = null,
    bias: ?*runtime.Instance = null,
    axis: ?u32 = null,
    epsilon: ?f64 = null,
};
