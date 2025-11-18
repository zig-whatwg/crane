//! WebIDL dictionary: OscillatorOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const OscillatorOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    type: ?anyopaque = null,
    frequency: ?f32 = null,
    detune: ?f32 = null,
    periodicWave: ?anyopaque = null,
};
