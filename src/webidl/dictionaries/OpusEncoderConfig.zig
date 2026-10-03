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

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "frameDuration", "complexity", "packetlossperc" };
};
