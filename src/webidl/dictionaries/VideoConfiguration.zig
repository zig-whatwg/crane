//! WebIDL dictionary: VideoConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const VideoConfiguration = struct {
    contentType: runtime.DOMString,
    width: u32,
    height: u32,
    bitrate: u64,
    framerate: f64,
    hasAlphaChannel: ?bool = null,
    hdrMetadataType: ?enums.HdrMetadataType = null,
    colorGamut: ?enums.ColorGamut = null,
    transferFunction: ?enums.TransferFunction = null,
    scalabilityMode: ?runtime.DOMString = null,
    spatialScalability: ?bool = null,
};
