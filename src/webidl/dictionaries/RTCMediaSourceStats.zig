//! WebIDL dictionary: RTCMediaSourceStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCStats = @import("RTCStats.zig").RTCStats;

pub const RTCMediaSourceStats = struct {
    // Inherited from RTCStats
    base: RTCStats,

    trackIdentifier: runtime.DOMString,
    kind: runtime.DOMString,
};
