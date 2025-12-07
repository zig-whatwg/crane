//! WebIDL dictionary: OpusEncoderConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
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
};
