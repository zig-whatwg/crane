//! WebIDL dictionary: BiquadFilterOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const BiquadFilterOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    @"type": ?enums.BiquadFilterType = null,
    Q: ?f32 = null,
    detune: ?f32 = null,
    frequency: ?f32 = null,
    gain: ?f32 = null,
};
