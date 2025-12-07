//! WebIDL dictionary: MLInstanceNormalizationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLInstanceNormalizationOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    scale: ?*runtime.Instance = null,
    bias: ?*runtime.Instance = null,
    epsilon: ?f64 = null,
    layout: ?enums.MLInputOperandLayout = null,
};
