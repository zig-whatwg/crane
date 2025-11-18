//! WebIDL dictionary: MLGemmOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLGemmOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    c: ?anyopaque = null,
    alpha: ?f64 = null,
    beta: ?f64 = null,
    aTranspose: ?bool = null,
    bTranspose: ?bool = null,
};
