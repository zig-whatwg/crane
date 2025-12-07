//! WebIDL dictionary: AudioDecoderConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const AudioDecoderConfig = struct {
    codec: runtime.DOMString,
    sampleRate: u32,
    numberOfChannels: u32,
    description: ?typedefs.AllowSharedBufferSource = null,
};
