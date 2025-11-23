//! WebIDL dictionary: MediaTrackCapabilities
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MediaTrackCapabilities = struct {
    width: ?*const anyopaque = null,
    height: ?*const anyopaque = null,
    aspectRatio: ?*const anyopaque = null,
    frameRate: ?*const anyopaque = null,
    facingMode: ?*const anyopaque = null,
    resizeMode: ?*const anyopaque = null,
    sampleRate: ?*const anyopaque = null,
    sampleSize: ?*const anyopaque = null,
    echoCancellation: ?*const anyopaque = null,
    autoGainControl: ?*const anyopaque = null,
    noiseSuppression: ?*const anyopaque = null,
    latency: ?*const anyopaque = null,
    channelCount: ?*const anyopaque = null,
    deviceId: ?runtime.DOMString = null,
    groupId: ?runtime.DOMString = null,
    backgroundBlur: ?*const anyopaque = null,
};
