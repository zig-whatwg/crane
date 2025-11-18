//! WebIDL dictionary: RTCSentRtpStreamStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCRtpStreamStats = @import("RTCRtpStreamStats.zig").RTCRtpStreamStats;

pub const RTCSentRtpStreamStats = struct {
    // Inherited from RTCRtpStreamStats
    base: RTCRtpStreamStats,

    packetsSent: ?u64 = null,
    bytesSent: ?u64 = null,
};
