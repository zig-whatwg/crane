//! WebIDL dictionary: MediaTrackSettings
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MediaTrackSettings = struct {
    width: ?u32 = null,
    height: ?u32 = null,
    aspectRatio: ?f64 = null,
    frameRate: ?f64 = null,
    facingMode: ?runtime.DOMString = null,
    resizeMode: ?runtime.DOMString = null,
    sampleRate: ?u32 = null,
    sampleSize: ?u32 = null,
    echoCancellation: ?anyopaque = null,
    autoGainControl: ?bool = null,
    noiseSuppression: ?bool = null,
    latency: ?f64 = null,
    channelCount: ?u32 = null,
    deviceId: ?runtime.DOMString = null,
    groupId: ?runtime.DOMString = null,
    backgroundBlur: ?bool = null,
};
