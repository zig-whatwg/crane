//! WebIDL dictionary: AudioDataInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const AudioDataInit = struct {
    format: enums.AudioSampleFormat,
    sampleRate: f32,
    numberOfFrames: u32,
    numberOfChannels: u32,
    timestamp: i64,
    data: typedefs.BufferSource,
    transfer: ?[]const *const anyopaque = null,
};
