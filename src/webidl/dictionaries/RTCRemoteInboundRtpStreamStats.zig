//! WebIDL dictionary: RTCRemoteInboundRtpStreamStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
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

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "roundTripTime", "totalRoundTripTime", "fractionLost" };
};
