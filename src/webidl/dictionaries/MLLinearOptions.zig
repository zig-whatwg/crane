//! WebIDL dictionary: MLLinearOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLLinearOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    alpha: ?f64 = null,
    beta: ?f64 = null,
};
