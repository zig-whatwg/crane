//! WebIDL dictionary: MLHardSigmoidOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLHardSigmoidOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    alpha: ?f64 = null,
    beta: ?f64 = null,
};
