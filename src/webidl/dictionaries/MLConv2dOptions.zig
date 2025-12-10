//! WebIDL dictionary: MLConv2dOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLConv2dOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    padding: ?[]const runtime.JSValue = null,
    strides: ?[]const runtime.JSValue = null,
    dilations: ?[]const runtime.JSValue = null,
    groups: ?u32 = null,
    inputLayout: ?enums.MLInputOperandLayout = null,
    filterLayout: ?enums.MLConv2dFilterOperandLayout = null,
    bias: ?*runtime.Instance = null,
};
