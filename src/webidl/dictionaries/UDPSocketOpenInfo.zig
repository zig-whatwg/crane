//! WebIDL dictionary: UDPSocketOpenInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const UDPSocketOpenInfo = struct {
    readable: ?*runtime.Instance = null,
    writable: ?*runtime.Instance = null,
    remoteAddress: ?runtime.DOMString = null,
    remotePort: ?u16 = null,
    localAddress: ?runtime.DOMString = null,
    localPort: ?u16 = null,
    multicastController: ?*runtime.Instance = null,
};
