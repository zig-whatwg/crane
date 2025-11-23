//! WebIDL dictionary: UDPMessage
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const UDPMessage = struct {
    data: ?*const anyopaque = null,
    remoteAddress: ?runtime.DOMString = null,
    remotePort: ?u16 = null,
    dnsQueryType: ?*const anyopaque = null,
};
