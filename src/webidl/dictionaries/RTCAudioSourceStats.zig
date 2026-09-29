//! WebIDL dictionary: RTCAudioSourceStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCMediaSourceStats = @import("RTCMediaSourceStats.zig").RTCMediaSourceStats;

pub const RTCAudioSourceStats = struct {
    // Inherited from RTCMediaSourceStats
    base: RTCMediaSourceStats,

    audioLevel: ?f64 = null,
    totalAudioEnergy: ?f64 = null,
    totalSamplesDuration: ?f64 = null,
    echoReturnLoss: ?f64 = null,
    echoReturnLossEnhancement: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "audioLevel", "totalAudioEnergy", "totalSamplesDuration", "echoReturnLoss", "echoReturnLossEnhancement" };
};
