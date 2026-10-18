//! WebIDL dictionary: OpusEncoderConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const OpusEncoderConfig = struct {
    format: ?enums.OpusBitstreamFormat = null,
    signal: ?enums.OpusSignal = null,
    application: ?enums.OpusApplication = null,
    frameDuration: ?u64 = null,
    complexity: ?u32 = null,
    packetlossperc: ?u32 = null,
    useinbandfec: ?bool = null,
    usedtx: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "format", .{ .string = "opus" } },
        .{ "signal", .{ .string = "auto" } },
        .{ "application", .{ .string = "audio" } },
        .{ "frameDuration", .{ .number = 20000 } },
        .{ "packetlossperc", .{ .number = 0 } },
        .{ "useinbandfec", .{ .boolean = false } },
        .{ "usedtx", .{ .boolean = false } },
    };

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "frameDuration", "complexity", "packetlossperc" };
};
