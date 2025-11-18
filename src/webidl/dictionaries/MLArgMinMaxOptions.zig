//! WebIDL dictionary: MLArgMinMaxOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLArgMinMaxOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    keepDimensions: ?bool = null,
    outputDataType: ?anyopaque = null,
};
