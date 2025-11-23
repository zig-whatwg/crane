//! WebIDL dictionary: StereoPannerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const StereoPannerOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    pan: ?f32 = null,
};
