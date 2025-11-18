//! WebIDL dictionary: MLTriangularOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLTriangularOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    upper: ?bool = null,
    diagonal: ?i32 = null,
};
