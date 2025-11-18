//! WebIDL dictionary: RTCReceivedRtpStreamStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCRtpStreamStats = @import("RTCRtpStreamStats.zig").RTCRtpStreamStats;

pub const RTCReceivedRtpStreamStats = struct {
    // Inherited from RTCRtpStreamStats
    base: RTCRtpStreamStats,

    packetsReceived: ?u64 = null,
    packetsReceivedWithEct1: ?u64 = null,
    packetsReceivedWithCe: ?u64 = null,
    packetsReportedAsLost: ?u64 = null,
    packetsReportedAsLostButRecovered: ?u64 = null,
    packetsLost: ?i64 = null,
    jitter: ?f64 = null,
};
