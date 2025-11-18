//! WebIDL dictionary: OpusEncoderConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const OpusEncoderConfig = struct {
    format: ?anyopaque = null,
    signal: ?anyopaque = null,
    application: ?anyopaque = null,
    frameDuration: ?u64 = null,
    complexity: ?u32 = null,
    packetlossperc: ?u32 = null,
    useinbandfec: ?bool = null,
    usedtx: ?bool = null,
};
