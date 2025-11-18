//! WebIDL dictionary: MLTransposeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLTransposeOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    permutation: ?anyopaque = null,
};
