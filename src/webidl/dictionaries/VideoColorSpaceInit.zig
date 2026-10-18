//! WebIDL dictionary: VideoColorSpaceInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const VideoColorSpaceInit = struct {
    primaries: ?enums.VideoColorPrimaries = null,
    transfer: ?enums.VideoTransferCharacteristics = null,
    matrix: ?enums.VideoMatrixCoefficients = null,
    fullRange: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "primaries", .null },
        .{ "transfer", .null },
        .{ "matrix", .null },
        .{ "fullRange", .null },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "primaries", "transfer", "matrix", "fullRange" };
};
