//! WebIDL dictionary: AacEncoderConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const AacEncoderConfig = struct {
    format: ?enums.AacBitstreamFormat = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "format", .{ .string = "aac" } },
    };
};
