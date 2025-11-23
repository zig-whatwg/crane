//! WebIDL dictionary: WebTransportOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const WebTransportOptions = struct {
    allowPooling: ?bool = null,
    requireUnreliable: ?bool = null,
    serverCertificateHashes: ?*const anyopaque = null,
    congestionControl: ?*const anyopaque = null,
    anticipatedConcurrentIncomingUnidirectionalStreams: ?u16 = null,
    anticipatedConcurrentIncomingBidirectionalStreams: ?u16 = null,
    protocols: ?*const anyopaque = null,
    datagramsReadableMode: ?*const anyopaque = null,
};
