//! WebIDL dictionary: DynamicsCompressorOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const DynamicsCompressorOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    attack: ?f32 = null,
    knee: ?f32 = null,
    ratio: ?f32 = null,
    release: ?f32 = null,
    threshold: ?f32 = null,
};
