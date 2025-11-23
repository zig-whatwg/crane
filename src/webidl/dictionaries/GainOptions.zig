//! WebIDL dictionary: GainOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const GainOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    gain: ?f32 = null,
};
