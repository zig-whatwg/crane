//! WebIDL dictionary: RTCIceCandidatePairStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCStats = @import("RTCStats.zig").RTCStats;

pub const RTCIceCandidatePairStats = struct {
    // Inherited from RTCStats
    base: RTCStats,

    transportId: runtime.DOMString,
    localCandidateId: runtime.DOMString,
    remoteCandidateId: runtime.DOMString,
    state: anyopaque,
    nominated: ?bool = null,
    packetsSent: ?u64 = null,
    packetsReceived: ?u64 = null,
    bytesSent: ?u64 = null,
    bytesReceived: ?u64 = null,
    lastPacketSentTimestamp: ?anyopaque = null,
    lastPacketReceivedTimestamp: ?anyopaque = null,
    totalRoundTripTime: ?f64 = null,
    currentRoundTripTime: ?f64 = null,
    availableOutgoingBitrate: ?f64 = null,
    availableIncomingBitrate: ?f64 = null,
    requestsReceived: ?u64 = null,
    requestsSent: ?u64 = null,
    responsesReceived: ?u64 = null,
    responsesSent: ?u64 = null,
    consentRequestsSent: ?u64 = null,
    packetsDiscardedOnSend: ?u32 = null,
    bytesDiscardedOnSend: ?u64 = null,
};
