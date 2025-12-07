//! WebIDL dictionary: UDPMessage
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const UDPMessage = struct {
    data: ?typedefs.BufferSource = null,
    remoteAddress: ?runtime.DOMString = null,
    remotePort: ?u16 = null,
    dnsQueryType: ?enums.SocketDnsQueryType = null,
};
