//! WebIDL dictionary: AnalyserOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const AnalyserOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    fftSize: ?u32 = null,
    maxDecibels: ?f64 = null,
    minDecibels: ?f64 = null,
    smoothingTimeConstant: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "maxDecibels", "minDecibels", "smoothingTimeConstant" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "fftSize", .{ .number = 2048 } },
        .{ "maxDecibels", .{ .number = -30 } },
        .{ "minDecibels", .{ .number = -100 } },
        .{ "smoothingTimeConstant", .{ .number = 0.8 } },
    };
};
