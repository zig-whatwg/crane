//! WebIDL dictionary: MLPool2dOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLPool2dOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    windowDimensions: ?[]const *const anyopaque = null,
    padding: ?[]const *const anyopaque = null,
    strides: ?[]const *const anyopaque = null,
    dilations: ?[]const *const anyopaque = null,
    layout: ?enums.MLInputOperandLayout = null,
    outputShapeRounding: ?enums.MLRoundingType = null,
    outputSizes: ?[]const *const anyopaque = null,
};
