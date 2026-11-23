//! WebIDL dictionary: AudioConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AudioConfiguration = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    contentType: runtime.DOMString,
    channels: ?runtime.DOMString = null,
    bitrate: ?u64 = null,
    samplerate: ?u32 = null,
    spatialRendering: ?bool = null,
};
