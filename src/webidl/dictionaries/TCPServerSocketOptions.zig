//! WebIDL dictionary: TCPServerSocketOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const TCPServerSocketOptions = struct {
    localPort: ?u16 = null,
    backlog: ?u32 = null,
    ipv6Only: ?bool = null,
};
