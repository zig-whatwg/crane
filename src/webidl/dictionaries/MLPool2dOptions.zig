//! WebIDL dictionary: MLPool2dOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLPool2dOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    windowDimensions: ?*const anyopaque = null,
    padding: ?*const anyopaque = null,
    strides: ?*const anyopaque = null,
    dilations: ?*const anyopaque = null,
    layout: ?*const anyopaque = null,
    outputShapeRounding: ?*const anyopaque = null,
    outputSizes: ?*const anyopaque = null,
};
