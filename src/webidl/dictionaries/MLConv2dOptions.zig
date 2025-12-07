//! WebIDL dictionary: MLConv2dOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLConv2dOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    padding: ?[]const *const anyopaque = null,
    strides: ?[]const *const anyopaque = null,
    dilations: ?[]const *const anyopaque = null,
    groups: ?u32 = null,
    inputLayout: ?enums.MLInputOperandLayout = null,
    filterLayout: ?enums.MLConv2dFilterOperandLayout = null,
    bias: ?*runtime.Instance = null,
};
