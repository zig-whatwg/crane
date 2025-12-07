//! WebIDL dictionary: UDPSocketOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const UDPSocketOptions = struct {
    remoteAddress: ?runtime.DOMString = null,
    remotePort: ?u16 = null,
    localAddress: ?runtime.DOMString = null,
    localPort: ?u16 = null,
    sendBufferSize: ?u32 = null,
    receiveBufferSize: ?u32 = null,
    dnsQueryType: ?enums.SocketDnsQueryType = null,
    ipv6Only: ?bool = null,
    multicastTimeToLive: ?u8 = null,
    multicastLoopback: ?bool = null,
    multicastAllowAddressSharing: ?bool = null,
};
