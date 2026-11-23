//! WebIDL dictionary: MLTriangularOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLTriangularOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    upper: ?bool = null,
    diagonal: ?i32 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "upper", .{ .boolean = true } },
        .{ "diagonal", .{ .number = 0 } },
    };

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"diagonal"};
};
