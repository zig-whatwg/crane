//! WebIDL dictionary: FlacEncoderConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const FlacEncoderConfig = struct {
    blockSize: ?u32 = null,
    compressLevel: ?u32 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "blockSize", .{ .number = 0 } },
        .{ "compressLevel", .{ .number = 5 } },
    };

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "blockSize", "compressLevel" };
};
