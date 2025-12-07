//! WebIDL dictionary: WebTransportConnectionStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const WebTransportDatagramStats = @import("WebTransportDatagramStats.zig").WebTransportDatagramStats;

pub const WebTransportConnectionStats = struct {
    bytesSent: ?u64 = null,
    packetsSent: ?u64 = null,
    bytesLost: ?u64 = null,
    packetsLost: ?u64 = null,
    bytesReceived: ?u64 = null,
    packetsReceived: ?u64 = null,
    smoothedRtt: typedefs.DOMHighResTimeStamp,
    rttVariation: typedefs.DOMHighResTimeStamp,
    minRtt: typedefs.DOMHighResTimeStamp,
    datagrams: WebTransportDatagramStats,
    estimatedSendRate: ?u64 = null,
    atSendCapacity: ?bool = null,
};
