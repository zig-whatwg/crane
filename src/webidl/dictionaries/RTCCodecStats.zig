//! WebIDL dictionary: RTCCodecStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCStats = @import("RTCStats.zig").RTCStats;

pub const RTCCodecStats = struct {
    // Inherited from RTCStats
    base: RTCStats,

    payloadType: u32,
    transportId: runtime.DOMString,
    mimeType: runtime.DOMString,
    clockRate: ?u32 = null,
    channels: ?u32 = null,
    sdpFmtpLine: ?runtime.DOMString = null,
};
