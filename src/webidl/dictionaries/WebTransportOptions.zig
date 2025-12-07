//! WebIDL dictionary: WebTransportOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const WebTransportHash = @import("WebTransportHash.zig").WebTransportHash;

pub const WebTransportOptions = struct {
    allowPooling: ?bool = null,
    requireUnreliable: ?bool = null,
    serverCertificateHashes: ?[]const WebTransportHash = null,
    congestionControl: ?enums.WebTransportCongestionControl = null,
    anticipatedConcurrentIncomingUnidirectionalStreams: ?u16 = null,
    anticipatedConcurrentIncomingBidirectionalStreams: ?u16 = null,
    protocols: ?[]const runtime.DOMString = null,
    datagramsReadableMode: ?enums.DatagramsReadableMode = null,
};
