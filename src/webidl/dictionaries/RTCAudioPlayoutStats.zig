//! WebIDL dictionary: RTCAudioPlayoutStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCStats = @import("RTCStats.zig").RTCStats;

pub const RTCAudioPlayoutStats = struct {
    // Inherited from RTCStats
    base: RTCStats,

    kind: runtime.DOMString,
    synthesizedSamplesDuration: ?f64 = null,
    synthesizedSamplesEvents: ?u32 = null,
    totalSamplesDuration: ?f64 = null,
    totalPlayoutDelay: ?f64 = null,
    totalSamplesCount: ?u64 = null,
};
