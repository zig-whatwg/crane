//! WebIDL dictionary: RTCLocalIceCandidateInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCIceCandidateInit = @import("RTCIceCandidateInit.zig").RTCIceCandidateInit;

pub const RTCLocalIceCandidateInit = struct {
    // Inherited from RTCIceCandidateInit
    base: RTCIceCandidateInit,

    relayProtocol: ?anyopaque = null,
    url: ?anyopaque = null,
};
