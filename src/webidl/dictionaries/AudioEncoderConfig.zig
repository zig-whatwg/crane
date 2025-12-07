//! WebIDL dictionary: AudioEncoderConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const FlacEncoderConfig = @import("FlacEncoderConfig.zig").FlacEncoderConfig;
const OpusEncoderConfig = @import("OpusEncoderConfig.zig").OpusEncoderConfig;
const AacEncoderConfig = @import("AacEncoderConfig.zig").AacEncoderConfig;

pub const AudioEncoderConfig = struct {
    codec: runtime.DOMString,
    sampleRate: u32,
    numberOfChannels: u32,
    bitrate: ?u64 = null,
    bitrateMode: ?enums.BitrateMode = null,
    aac: ?AacEncoderConfig = null,
    flac: ?FlacEncoderConfig = null,
    opus: ?OpusEncoderConfig = null,
};
