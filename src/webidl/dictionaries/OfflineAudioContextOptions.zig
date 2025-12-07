//! WebIDL dictionary: OfflineAudioContextOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const OfflineAudioContextOptions = struct {
    numberOfChannels: ?u32 = null,
    length: u32,
    sampleRate: f32,
    renderSizeHint: ?*const anyopaque = null,
};
