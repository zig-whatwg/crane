//! WebIDL dictionary: OpusEncoderConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const OpusEncoderConfig = struct {
    format: ?*const anyopaque = null,
    signal: ?*const anyopaque = null,
    application: ?*const anyopaque = null,
    frameDuration: ?u64 = null,
    complexity: ?u32 = null,
    packetlossperc: ?u32 = null,
    useinbandfec: ?bool = null,
    usedtx: ?bool = null,
};
