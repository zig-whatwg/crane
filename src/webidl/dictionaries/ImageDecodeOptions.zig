//! WebIDL dictionary: ImageDecodeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ImageDecodeOptions = struct {
    frameIndex: ?u32 = null,
    completeFramesOnly: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "frameIndex", .{ .number = 0 } },
        .{ "completeFramesOnly", .{ .boolean = true } },
    };

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"frameIndex"};
};
