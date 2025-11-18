//! WebIDL dictionary: RTCIceCandidateStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCStats = @import("RTCStats.zig").RTCStats;

pub const RTCIceCandidateStats = struct {
    // Inherited from RTCStats
    base: RTCStats,

    transportId: runtime.DOMString,
    address: ?anyopaque = null,
    port: ?i32 = null,
    protocol: ?runtime.DOMString = null,
    candidateType: anyopaque,
    priority: ?i32 = null,
    url: ?runtime.DOMString = null,
    relayProtocol: ?anyopaque = null,
    foundation: ?runtime.DOMString = null,
    relatedAddress: ?runtime.DOMString = null,
    relatedPort: ?i32 = null,
    usernameFragment: ?runtime.DOMString = null,
    tcpType: ?anyopaque = null,
};
