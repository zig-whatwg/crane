//! WebIDL dictionary: AudioDataInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const AudioDataInit = struct {
    format: enums.AudioSampleFormat,
    sampleRate: f32,
    numberOfFrames: u32,
    numberOfChannels: u32,
    timestamp: i64,
    data: typedefs.AllowSharedBufferSource,
    transfer: ?[]const runtime.JSValue = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"sampleRate"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "transfer", .empty_sequence },
    };

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "numberOfFrames", "numberOfChannels", "timestamp" };
};
