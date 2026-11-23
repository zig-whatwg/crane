//! WebIDL dictionary: AudioEncoderSupport
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioEncoderConfig = @import("AudioEncoderConfig.zig").AudioEncoderConfig;

pub const AudioEncoderSupport = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    supported: ?bool = null,
    config: ?AudioEncoderConfig = null,
};
