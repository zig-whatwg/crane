//! WebIDL dictionary: VideoEncoderConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const VideoEncoderConfig = struct {
    codec: runtime.DOMString,
    width: u32,
    height: u32,
    displayWidth: ?u32 = null,
    displayHeight: ?u32 = null,
    bitrate: ?u64 = null,
    framerate: ?f64 = null,
    hardwareAcceleration: ?anyopaque = null,
    alpha: ?anyopaque = null,
    scalabilityMode: ?runtime.DOMString = null,
    bitrateMode: ?anyopaque = null,
    latencyMode: ?anyopaque = null,
    contentHint: ?runtime.DOMString = null,
};
