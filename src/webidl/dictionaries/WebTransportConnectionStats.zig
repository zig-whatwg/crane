//! WebIDL dictionary: WebTransportConnectionStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const WebTransportDatagramStats = @import("WebTransportDatagramStats.zig").WebTransportDatagramStats;

pub const WebTransportConnectionStats = struct {
    bytesSent: ?u64 = null,
    bytesSentOverhead: ?u64 = null,
    bytesAcknowledged: ?u64 = null,
    packetsSent: ?u64 = null,
    bytesLost: ?u64 = null,
    packetsLost: ?u64 = null,
    bytesReceived: ?u64 = null,
    packetsReceived: ?u64 = null,
    smoothedRtt: ?typedefs.DOMHighResTimeStamp = null,
    rttVariation: ?typedefs.DOMHighResTimeStamp = null,
    minRtt: ?typedefs.DOMHighResTimeStamp = null,
    datagrams: WebTransportDatagramStats,
    estimatedSendRate: ?u64 = null,
    atSendCapacity: ?bool = null,
};
