//! WebIDL dictionary: AudioBufferOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const AudioBufferOptions = struct {
    numberOfChannels: ?u32 = null,
    length: u32,
    sampleRate: f32,
};
