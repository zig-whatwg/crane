//! WebIDL dictionary: AudioBufferOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AudioBufferOptions = struct {
    numberOfChannels: ?u32 = null,
    length: u32,
    sampleRate: f32,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"sampleRate"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "numberOfChannels", .{ .number = 1 } },
    };
};
