//! WebIDL dictionary: VideoDecoderConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const VideoColorSpaceInit = @import("VideoColorSpaceInit.zig").VideoColorSpaceInit;

pub const VideoDecoderConfig = struct {
    codec: runtime.DOMString,
    description: ?typedefs.AllowSharedBufferSource = null,
    codedWidth: ?u32 = null,
    codedHeight: ?u32 = null,
    displayAspectWidth: ?u32 = null,
    displayAspectHeight: ?u32 = null,
    colorSpace: ?VideoColorSpaceInit = null,
    hardwareAcceleration: ?enums.HardwareAcceleration = null,
    optimizeForLatency: ?bool = null,
    rotation: ?f64 = null,
    flip: ?bool = null,
};
