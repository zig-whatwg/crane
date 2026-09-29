//! WebIDL dictionary: AudioBufferSourceOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AudioBufferSourceOptions = struct {
    buffer: ?*runtime.Instance = null,
    detune: ?f32 = null,
    loop: ?bool = null,
    loopEnd: ?f64 = null,
    loopStart: ?f64 = null,
    playbackRate: ?f32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "detune", "loopEnd", "loopStart", "playbackRate" };
};
