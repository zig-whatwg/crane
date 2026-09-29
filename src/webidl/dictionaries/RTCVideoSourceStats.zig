//! WebIDL dictionary: RTCVideoSourceStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCMediaSourceStats = @import("RTCMediaSourceStats.zig").RTCMediaSourceStats;

pub const RTCVideoSourceStats = struct {
    // Inherited from RTCMediaSourceStats
    base: RTCMediaSourceStats,

    width: ?u32 = null,
    height: ?u32 = null,
    frames: ?u32 = null,
    framesPerSecond: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"framesPerSecond"};
};
