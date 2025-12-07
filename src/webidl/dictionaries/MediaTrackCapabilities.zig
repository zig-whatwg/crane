//! WebIDL dictionary: MediaTrackCapabilities
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const ULongRange = @import("ULongRange.zig").ULongRange;
const DoubleRange = @import("DoubleRange.zig").DoubleRange;
const MediaSettingsRange = @import("MediaSettingsRange.zig").MediaSettingsRange;

pub const MediaTrackCapabilities = struct {
    width: ?ULongRange = null,
    height: ?ULongRange = null,
    aspectRatio: ?DoubleRange = null,
    frameRate: ?DoubleRange = null,
    facingMode: ?[]const runtime.DOMString = null,
    resizeMode: ?[]const runtime.DOMString = null,
    sampleRate: ?ULongRange = null,
    sampleSize: ?ULongRange = null,
    echoCancellation: ?[]const *const anyopaque = null,
    autoGainControl: ?[]const bool = null,
    noiseSuppression: ?[]const bool = null,
    latency: ?DoubleRange = null,
    channelCount: ?ULongRange = null,
    deviceId: ?runtime.DOMString = null,
    groupId: ?runtime.DOMString = null,
    backgroundBlur: ?[]const bool = null,
    whiteBalanceMode: ?[]const runtime.DOMString = null,
    exposureMode: ?[]const runtime.DOMString = null,
    focusMode: ?[]const runtime.DOMString = null,
    exposureCompensation: ?MediaSettingsRange = null,
    exposureTime: ?MediaSettingsRange = null,
    colorTemperature: ?MediaSettingsRange = null,
    iso: ?MediaSettingsRange = null,
    brightness: ?MediaSettingsRange = null,
    contrast: ?MediaSettingsRange = null,
    saturation: ?MediaSettingsRange = null,
    sharpness: ?MediaSettingsRange = null,
    focusDistance: ?MediaSettingsRange = null,
    pan: ?MediaSettingsRange = null,
    tilt: ?MediaSettingsRange = null,
    zoom: ?MediaSettingsRange = null,
    torch: ?[]const bool = null,
    displaySurface: ?runtime.DOMString = null,
    logicalSurface: ?bool = null,
    cursor: ?[]const runtime.DOMString = null,
};
