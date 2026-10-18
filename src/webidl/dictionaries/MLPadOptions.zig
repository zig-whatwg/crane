//! WebIDL dictionary: MLPadOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLPadOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    mode: ?enums.MLPaddingMode = null,
    value: ?typedefs.MLNumber = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "mode", .{ .string = "constant" } },
        .{ "value", .{ .number = 0 } },
    };
};
