//! WebIDL dictionary: MediaTrackConstraintSet
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const MediaTrackConstraintSet = struct {
    width: ?typedefs.ConstrainULong = null,
    height: ?typedefs.ConstrainULong = null,
    aspectRatio: ?typedefs.ConstrainDouble = null,
    frameRate: ?typedefs.ConstrainDouble = null,
    facingMode: ?typedefs.ConstrainDOMString = null,
    resizeMode: ?typedefs.ConstrainDOMString = null,
    sampleRate: ?typedefs.ConstrainULong = null,
    sampleSize: ?typedefs.ConstrainULong = null,
    echoCancellation: ?typedefs.ConstrainBooleanOrDOMString = null,
    autoGainControl: ?typedefs.ConstrainBoolean = null,
    noiseSuppression: ?typedefs.ConstrainBoolean = null,
    latency: ?typedefs.ConstrainDouble = null,
    channelCount: ?typedefs.ConstrainULong = null,
    deviceId: ?typedefs.ConstrainDOMString = null,
    groupId: ?typedefs.ConstrainDOMString = null,
    backgroundBlur: ?typedefs.ConstrainBoolean = null,
    whiteBalanceMode: ?typedefs.ConstrainDOMString = null,
    exposureMode: ?typedefs.ConstrainDOMString = null,
    focusMode: ?typedefs.ConstrainDOMString = null,
    pointsOfInterest: ?typedefs.ConstrainPoint2D = null,
    exposureCompensation: ?typedefs.ConstrainDouble = null,
    exposureTime: ?typedefs.ConstrainDouble = null,
    colorTemperature: ?typedefs.ConstrainDouble = null,
    iso: ?typedefs.ConstrainDouble = null,
    brightness: ?typedefs.ConstrainDouble = null,
    contrast: ?typedefs.ConstrainDouble = null,
    saturation: ?typedefs.ConstrainDouble = null,
    sharpness: ?typedefs.ConstrainDouble = null,
    focusDistance: ?typedefs.ConstrainDouble = null,
    pan: ?*const anyopaque = null,
    tilt: ?*const anyopaque = null,
    zoom: ?*const anyopaque = null,
    torch: ?typedefs.ConstrainBoolean = null,
    displaySurface: ?typedefs.ConstrainDOMString = null,
    logicalSurface: ?typedefs.ConstrainBoolean = null,
    cursor: ?typedefs.ConstrainDOMString = null,
    restrictOwnAudio: ?typedefs.ConstrainBoolean = null,
    suppressLocalAudioPlayback: ?typedefs.ConstrainBoolean = null,
};
