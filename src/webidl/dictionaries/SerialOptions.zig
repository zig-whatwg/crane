//! WebIDL dictionary: SerialOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const SerialOptions = struct {
    baudRate: u32,
    dataBits: ?u8 = null,
    stopBits: ?u8 = null,
    parity: ?enums.ParityType = null,
    bufferSize: ?u32 = null,
    flowControl: ?enums.FlowControlType = null,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "baudRate", "dataBits", "stopBits", "bufferSize" };
};
