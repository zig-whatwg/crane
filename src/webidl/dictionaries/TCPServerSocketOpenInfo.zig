//! WebIDL dictionary: TCPServerSocketOpenInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const TCPServerSocketOpenInfo = struct {
    readable: ?*runtime.Instance = null,
    localAddress: ?runtime.DOMString = null,
    localPort: ?u16 = null,
};
