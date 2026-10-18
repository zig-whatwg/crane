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

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "dataBits", .{ .number = 8 } },
        .{ "stopBits", .{ .number = 1 } },
        .{ "parity", .{ .string = "none" } },
        .{ "bufferSize", .{ .number = 255 } },
        .{ "flowControl", .{ .string = "none" } },
    };

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "baudRate", "dataBits", "stopBits", "bufferSize" };
};
