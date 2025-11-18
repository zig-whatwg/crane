//! WebIDL dictionary: TCPSocketOpenInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const TCPSocketOpenInfo = struct {
    readable: ?anyopaque = null,
    writable: ?anyopaque = null,
    remoteAddress: ?runtime.DOMString = null,
    remotePort: ?u16 = null,
    localAddress: ?runtime.DOMString = null,
    localPort: ?u16 = null,
};
