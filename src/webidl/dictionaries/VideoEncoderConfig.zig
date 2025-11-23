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
    hardwareAcceleration: ?*const anyopaque = null,
    alpha: ?*const anyopaque = null,
    scalabilityMode: ?runtime.DOMString = null,
    bitrateMode: ?*const anyopaque = null,
    latencyMode: ?*const anyopaque = null,
    contentHint: ?runtime.DOMString = null,
};
