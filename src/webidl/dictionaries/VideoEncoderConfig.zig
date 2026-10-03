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
    avc: ?AvcEncoderConfig = null,
    hevc: ?HevcEncoderConfig = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"framerate"};

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "width", "height", "displayWidth", "displayHeight", "bitrate" };
};
