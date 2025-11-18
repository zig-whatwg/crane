//! WebIDL dictionary: MLConvTranspose2dOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLConvTranspose2dOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    padding: ?anyopaque = null,
    strides: ?anyopaque = null,
    dilations: ?anyopaque = null,
    outputPadding: ?anyopaque = null,
    outputSizes: ?anyopaque = null,
    groups: ?u32 = null,
    inputLayout: ?anyopaque = null,
    filterLayout: ?anyopaque = null,
    bias: ?anyopaque = null,
};
