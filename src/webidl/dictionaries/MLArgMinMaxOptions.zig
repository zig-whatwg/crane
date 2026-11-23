//! WebIDL dictionary: MLArgMinMaxOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLArgMinMaxOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    keepDimensions: ?bool = null,
    outputDataType: ?enums.MLOperandDataType = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "keepDimensions", .{ .boolean = false } },
        .{ "outputDataType", .{ .string = "int32" } },
    };
};
