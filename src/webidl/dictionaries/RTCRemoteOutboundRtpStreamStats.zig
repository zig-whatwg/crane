//! WebIDL dictionary: RTCRemoteOutboundRtpStreamStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCSentRtpStreamStats = @import("RTCSentRtpStreamStats.zig").RTCSentRtpStreamStats;

pub const RTCRemoteOutboundRtpStreamStats = struct {
    // Inherited from RTCSentRtpStreamStats
    base: RTCSentRtpStreamStats,

    localId: ?runtime.DOMString = null,
    remoteTimestamp: ?anyopaque = null,
    reportsSent: ?u64 = null,
    roundTripTime: ?f64 = null,
    totalRoundTripTime: ?f64 = null,
    roundTripTimeMeasurements: ?u64 = null,
};
