//! WebIDL dictionary: AudioEncoderSupport
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const AudioEncoderConfig = @import("AudioEncoderConfig.zig").AudioEncoderConfig;

pub const AudioEncoderSupport = struct {
    supported: ?bool = null,
    config: ?AudioEncoderConfig = null,
};
