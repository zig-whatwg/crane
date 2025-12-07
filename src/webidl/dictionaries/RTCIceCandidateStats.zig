//! WebIDL dictionary: RTCIceCandidateStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const RTCStats = @import("RTCStats.zig").RTCStats;

pub const RTCIceCandidateStats = struct {
    // Inherited from RTCStats
    base: RTCStats,

    transportId: runtime.DOMString,
    address: ?runtime.DOMString = null,
    port: ?i32 = null,
    protocol: ?runtime.DOMString = null,
    candidateType: enums.RTCIceCandidateType,
    priority: ?i32 = null,
    url: ?runtime.DOMString = null,
    relayProtocol: ?enums.RTCIceServerTransportProtocol = null,
    foundation: ?runtime.DOMString = null,
    relatedAddress: ?runtime.DOMString = null,
    relatedPort: ?i32 = null,
    usernameFragment: ?runtime.DOMString = null,
    tcpType: ?enums.RTCIceTcpCandidateType = null,
};
