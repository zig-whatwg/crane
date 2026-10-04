//! WebIDL enum: AudioSessionType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const AudioSessionType = enum {
    _auto_,
    _playback_,
    _transient_,
    _transient_solo_,
    _ambient_,
    _play_and_record_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "auto", "playback", "transient", "transient-solo", "ambient", "play-and-record" };
};
