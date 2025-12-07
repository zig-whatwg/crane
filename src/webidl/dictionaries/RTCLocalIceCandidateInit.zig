//! WebIDL dictionary: RTCLocalIceCandidateInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const RTCIceCandidateInit = @import("RTCIceCandidateInit.zig").RTCIceCandidateInit;

pub const RTCLocalIceCandidateInit = struct {
    // Inherited from RTCIceCandidateInit
    base: RTCIceCandidateInit,

    relayProtocol: ?enums.RTCIceServerTransportProtocol = null,
    url: ?runtime.USVString = null,
};
