//! WebIDL dictionary: AudioDataInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AudioDataInit = struct {
    format: anyopaque,
    sampleRate: f32,
    numberOfFrames: u32,
    numberOfChannels: u32,
    timestamp: i64,
    data: anyopaque,
    transfer: ?anyopaque = null,
};
