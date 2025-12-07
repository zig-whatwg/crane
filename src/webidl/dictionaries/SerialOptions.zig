//! WebIDL dictionary: SerialOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const SerialOptions = struct {
    baudRate: u32,
    dataBits: ?u8 = null,
    stopBits: ?u8 = null,
    parity: ?enums.ParityType = null,
    bufferSize: ?u32 = null,
    flowControl: ?enums.FlowControlType = null,
};
