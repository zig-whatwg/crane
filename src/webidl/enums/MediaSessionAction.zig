//! WebIDL enum: MediaSessionAction
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const MediaSessionAction = enum {
    _play_,
    _pause_,
    _seekbackward_,
    _seekforward_,
    _previoustrack_,
    _nexttrack_,
    _skipad_,
    _stop_,
    _seekto_,
    _togglemicrophone_,
    _togglecamera_,
    _togglescreenshare_,
    _hangup_,
    _previousslide_,
    _nextslide_,
    _enterpictureinpicture_,
    _voiceactivity_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "play", "pause", "seekbackward", "seekforward", "previoustrack", "nexttrack", "skipad", "stop", "seekto", "togglemicrophone", "togglecamera", "togglescreenshare", "hangup", "previousslide", "nextslide", "enterpictureinpicture", "voiceactivity" };
};
