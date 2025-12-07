//! WebIDL dictionary: MediaTrackSettings
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const Point2D = @import("Point2D.zig").Point2D;

pub const MediaTrackSettings = struct {
    width: ?u32 = null,
    height: ?u32 = null,
    aspectRatio: ?f64 = null,
    frameRate: ?f64 = null,
    facingMode: ?runtime.DOMString = null,
    resizeMode: ?runtime.DOMString = null,
    sampleRate: ?u32 = null,
    sampleSize: ?u32 = null,
    echoCancellation: ?*const anyopaque = null,
    autoGainControl: ?bool = null,
    noiseSuppression: ?bool = null,
    latency: ?f64 = null,
    channelCount: ?u32 = null,
    deviceId: ?runtime.DOMString = null,
    groupId: ?runtime.DOMString = null,
    backgroundBlur: ?bool = null,
    whiteBalanceMode: ?runtime.DOMString = null,
    exposureMode: ?runtime.DOMString = null,
    focusMode: ?runtime.DOMString = null,
    pointsOfInterest: ?[]const Point2D = null,
    exposureCompensation: ?f64 = null,
    exposureTime: ?f64 = null,
    colorTemperature: ?f64 = null,
    iso: ?f64 = null,
    brightness: ?f64 = null,
    contrast: ?f64 = null,
    saturation: ?f64 = null,
    sharpness: ?f64 = null,
    focusDistance: ?f64 = null,
    pan: ?f64 = null,
    tilt: ?f64 = null,
    zoom: ?f64 = null,
    torch: ?bool = null,
    displaySurface: ?runtime.DOMString = null,
    logicalSurface: ?bool = null,
    cursor: ?runtime.DOMString = null,
    restrictOwnAudio: ?bool = null,
    suppressLocalAudioPlayback: ?bool = null,
    screenPixelRatio: ?f64 = null,
};
