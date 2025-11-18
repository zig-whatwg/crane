//! WebIDL dictionary: WebTransportOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const WebTransportOptions = struct {
    allowPooling: ?bool = null,
    requireUnreliable: ?bool = null,
    serverCertificateHashes: ?anyopaque = null,
    congestionControl: ?anyopaque = null,
    anticipatedConcurrentIncomingUnidirectionalStreams: ?anyopaque = null,
    anticipatedConcurrentIncomingBidirectionalStreams: ?anyopaque = null,
    protocols: ?anyopaque = null,
    datagramsReadableMode: ?anyopaque = null,
};
