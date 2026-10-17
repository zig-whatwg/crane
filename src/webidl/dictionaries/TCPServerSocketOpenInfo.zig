//! WebIDL dictionary: TCPServerSocketOpenInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const TCPServerSocketOpenInfo = struct {
    readable: ?*runtime.Instance = null,
    localAddress: ?runtime.DOMString = null,
    localPort: ?u16 = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "readable", "ReadableStream" },
    };
};
