//! WebIDL dictionary: AudioDataCopyToOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const AudioDataCopyToOptions = struct {
    planeIndex: u32,
    frameOffset: ?u32 = null,
    frameCount: ?u32 = null,
    format: ?enums.AudioSampleFormat = null,
};
