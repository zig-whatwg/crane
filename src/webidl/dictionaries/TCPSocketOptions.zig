//! WebIDL dictionary: TCPSocketOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const TCPSocketOptions = struct {
    sendBufferSize: ?u32 = null,
    receiveBufferSize: ?u32 = null,
    noDelay: ?bool = null,
    keepAliveDelay: ?u32 = null,
    dnsQueryType: ?enums.SocketDnsQueryType = null,
};
