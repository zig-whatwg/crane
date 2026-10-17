//! WebIDL dictionary: AudioConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AudioConfiguration = struct {
    contentType: runtime.DOMString,
    channels: ?runtime.DOMString = null,
    bitrate: ?u64 = null,
    samplerate: ?u32 = null,
    spatialRendering: ?bool = null,
};
