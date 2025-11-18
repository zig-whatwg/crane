//! WebIDL dictionary: MLPool2dOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLPool2dOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    windowDimensions: ?anyopaque = null,
    padding: ?anyopaque = null,
    strides: ?anyopaque = null,
    dilations: ?anyopaque = null,
    layout: ?anyopaque = null,
    outputShapeRounding: ?anyopaque = null,
    outputSizes: ?anyopaque = null,
};
