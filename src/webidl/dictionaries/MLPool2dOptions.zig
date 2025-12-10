//! WebIDL dictionary: MLPool2dOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLPool2dOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    windowDimensions: ?[]const runtime.JSValue = null,
    padding: ?[]const runtime.JSValue = null,
    strides: ?[]const runtime.JSValue = null,
    dilations: ?[]const runtime.JSValue = null,
    layout: ?enums.MLInputOperandLayout = null,
    outputShapeRounding: ?enums.MLRoundingType = null,
    outputSizes: ?[]const runtime.JSValue = null,
};
