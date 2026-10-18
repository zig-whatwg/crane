//! WebIDL dictionary: AudioDataCopyToOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const AudioDataCopyToOptions = struct {
    planeIndex: u32,
    frameOffset: ?u32 = null,
    frameCount: ?u32 = null,
    format: ?enums.AudioSampleFormat = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "frameOffset", .{ .number = 0 } },
    };

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "planeIndex", "frameOffset", "frameCount" };
};
