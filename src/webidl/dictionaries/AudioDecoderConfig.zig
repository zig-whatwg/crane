//! WebIDL dictionary: AudioDecoderConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AudioDecoderConfig = struct {
    codec: runtime.DOMString,
    sampleRate: u32,
    numberOfChannels: u32,
    description: ?anyopaque = null,
};
