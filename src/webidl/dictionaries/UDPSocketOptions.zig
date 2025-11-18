//! WebIDL dictionary: UDPSocketOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const UDPSocketOptions = struct {
    remoteAddress: ?runtime.DOMString = null,
    remotePort: ?u16 = null,
    localAddress: ?runtime.DOMString = null,
    localPort: ?u16 = null,
    sendBufferSize: ?u32 = null,
    receiveBufferSize: ?u32 = null,
    dnsQueryType: ?anyopaque = null,
    ipv6Only: ?bool = null,
    multicastTimeToLive: ?u8 = null,
    multicastLoopback: ?bool = null,
    multicastAllowAddressSharing: ?bool = null,
};
