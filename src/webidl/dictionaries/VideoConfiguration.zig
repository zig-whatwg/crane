//! WebIDL dictionary: VideoConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const VideoConfiguration = struct {
    contentType: runtime.DOMString,
    width: u32,
    height: u32,
    bitrate: u64,
    framerate: f64,
    hasAlphaChannel: ?bool = null,
    hdrMetadataType: ?*const anyopaque = null,
    colorGamut: ?*const anyopaque = null,
    transferFunction: ?*const anyopaque = null,
    scalabilityMode: ?runtime.DOMString = null,
    spatialScalability: ?bool = null,
};
