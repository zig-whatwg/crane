//! WebIDL dictionary: UDPSocketOpenInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const UDPSocketOpenInfo = struct {
    readable: ?*const anyopaque = null,
    writable: ?*const anyopaque = null,
    remoteAddress: ?runtime.DOMString = null,
    remotePort: ?u16 = null,
    localAddress: ?runtime.DOMString = null,
    localPort: ?u16 = null,
    multicastController: ?*const anyopaque = null,
};
