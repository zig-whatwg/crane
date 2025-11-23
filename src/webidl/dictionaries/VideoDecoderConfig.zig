//! WebIDL dictionary: VideoDecoderConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const VideoDecoderConfig = struct {
    codec: runtime.DOMString,
    description: ?*const anyopaque = null,
    codedWidth: ?u32 = null,
    codedHeight: ?u32 = null,
    displayAspectWidth: ?u32 = null,
    displayAspectHeight: ?u32 = null,
    colorSpace: ?*const anyopaque = null,
    hardwareAcceleration: ?*const anyopaque = null,
    optimizeForLatency: ?bool = null,
    rotation: ?f64 = null,
    flip: ?bool = null,
};
