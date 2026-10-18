//! WebIDL dictionary: DynamicsCompressorOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const DynamicsCompressorOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    attack: ?f32 = null,
    knee: ?f32 = null,
    ratio: ?f32 = null,
    release: ?f32 = null,
    threshold: ?f32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "attack", "knee", "ratio", "release", "threshold" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "attack", .{ .number = 0.003 } },
        .{ "knee", .{ .number = 30 } },
        .{ "ratio", .{ .number = 12 } },
        .{ "release", .{ .number = 0.25 } },
        .{ "threshold", .{ .number = -24 } },
    };
};
