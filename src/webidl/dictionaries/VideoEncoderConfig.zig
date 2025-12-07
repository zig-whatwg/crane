//! WebIDL dictionary: VideoEncoderConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const HevcEncoderConfig = @import("HevcEncoderConfig.zig").HevcEncoderConfig;
const AvcEncoderConfig = @import("AvcEncoderConfig.zig").AvcEncoderConfig;

pub const VideoEncoderConfig = struct {
    codec: runtime.DOMString,
    width: u32,
    height: u32,
    displayWidth: ?u32 = null,
    displayHeight: ?u32 = null,
    bitrate: ?u64 = null,
    framerate: ?f64 = null,
    hardwareAcceleration: ?enums.HardwareAcceleration = null,
    alpha: ?enums.AlphaOption = null,
    scalabilityMode: ?runtime.DOMString = null,
    bitrateMode: ?enums.VideoEncoderBitrateMode = null,
    latencyMode: ?enums.LatencyMode = null,
    contentHint: ?runtime.DOMString = null,
    hevc: ?HevcEncoderConfig = null,
    avc: ?AvcEncoderConfig = null,
};
