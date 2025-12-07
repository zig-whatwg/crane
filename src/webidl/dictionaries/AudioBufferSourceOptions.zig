//! WebIDL dictionary: AudioBufferSourceOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const AudioBufferSourceOptions = struct {
    buffer: ?*runtime.Instance = null,
    detune: ?f32 = null,
    loop: ?bool = null,
    loopEnd: ?f64 = null,
    loopStart: ?f64 = null,
    playbackRate: ?f32 = null,
};
