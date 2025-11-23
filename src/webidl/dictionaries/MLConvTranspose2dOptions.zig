//! WebIDL dictionary: MLConvTranspose2dOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLConvTranspose2dOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    padding: ?*const anyopaque = null,
    strides: ?*const anyopaque = null,
    dilations: ?*const anyopaque = null,
    outputPadding: ?*const anyopaque = null,
    outputSizes: ?*const anyopaque = null,
    groups: ?u32 = null,
    inputLayout: ?*const anyopaque = null,
    filterLayout: ?*const anyopaque = null,
    bias: ?*const anyopaque = null,
};
