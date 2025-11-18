//! WebIDL dictionary: SerialOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const SerialOptions = struct {
    baudRate: u32,
    dataBits: ?u8 = null,
    stopBits: ?u8 = null,
    parity: ?anyopaque = null,
    bufferSize: ?u32 = null,
    flowControl: ?anyopaque = null,
};
