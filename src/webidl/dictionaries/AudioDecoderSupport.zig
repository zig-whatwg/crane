//! WebIDL dictionary: AudioDecoderSupport
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioDecoderConfig = @import("AudioDecoderConfig.zig").AudioDecoderConfig;

pub const AudioDecoderSupport = struct {
    supported: ?bool = null,
    config: ?AudioDecoderConfig = null,
};
