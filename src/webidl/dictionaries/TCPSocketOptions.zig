//! WebIDL dictionary: TCPSocketOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const TCPSocketOptions = struct {
    sendBufferSize: ?u32 = null,
    receiveBufferSize: ?u32 = null,
    noDelay: ?bool = null,
    keepAliveDelay: ?u32 = null,
    dnsQueryType: ?anyopaque = null,
};
