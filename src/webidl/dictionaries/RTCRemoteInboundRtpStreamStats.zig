//! WebIDL dictionary: RTCRemoteInboundRtpStreamStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCReceivedRtpStreamStats = @import("RTCReceivedRtpStreamStats.zig").RTCReceivedRtpStreamStats;

pub const RTCRemoteInboundRtpStreamStats = struct {
    // Inherited from RTCReceivedRtpStreamStats
    base: RTCReceivedRtpStreamStats,

    localId: ?runtime.DOMString = null,
    roundTripTime: ?f64 = null,
    totalRoundTripTime: ?f64 = null,
    fractionLost: ?f64 = null,
    roundTripTimeMeasurements: ?u64 = null,
    packetsWithBleachedEct1Marking: ?u64 = null,
};
