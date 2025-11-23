//! WebIDL dictionary: RTCRtpStreamStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCStats = @import("RTCStats.zig").RTCStats;

pub const RTCRtpStreamStats = struct {
    // Inherited from RTCStats
    base: RTCStats,

    ssrc: u32,
    kind: runtime.DOMString,
    transportId: ?runtime.DOMString = null,
    codecId: ?runtime.DOMString = null,
};
