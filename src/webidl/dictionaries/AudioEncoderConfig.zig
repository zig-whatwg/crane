//! WebIDL dictionary: AudioEncoderConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AudioEncoderConfig = struct {
    codec: runtime.DOMString,
    sampleRate: u32,
    numberOfChannels: u32,
    bitrate: ?u64 = null,
    bitrateMode: ?anyopaque = null,
};
