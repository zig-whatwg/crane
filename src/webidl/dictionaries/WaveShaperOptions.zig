//! WebIDL dictionary: WaveShaperOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const WaveShaperOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    curve: ?[]const f32 = null,
    oversample: ?enums.OverSampleType = null,
};
