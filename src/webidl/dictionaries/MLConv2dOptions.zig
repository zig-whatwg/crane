//! WebIDL dictionary: MLConv2dOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLConv2dOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    padding: ?anyopaque = null,
    strides: ?anyopaque = null,
    dilations: ?anyopaque = null,
    groups: ?u32 = null,
    inputLayout: ?anyopaque = null,
    filterLayout: ?anyopaque = null,
    bias: ?anyopaque = null,
};
