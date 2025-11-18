//! WebIDL dictionary: MLSliceOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLSliceOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    strides: ?anyopaque = null,
};
