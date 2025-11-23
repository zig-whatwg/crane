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
};
