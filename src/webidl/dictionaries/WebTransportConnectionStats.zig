//! WebIDL dictionary: WebTransportConnectionStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const WebTransportConnectionStats = struct {
    bytesSent: ?u64 = null,
    packetsSent: ?u64 = null,
    bytesLost: ?u64 = null,
    packetsLost: ?u64 = null,
    bytesReceived: ?u64 = null,
    packetsReceived: ?u64 = null,
    smoothedRtt: anyopaque,
    rttVariation: anyopaque,
    minRtt: anyopaque,
    datagrams: anyopaque,
    estimatedSendRate: ?anyopaque = null,
    atSendCapacity: ?bool = null,
};
