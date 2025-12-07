//! WebIDL dictionary: OscillatorOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const OscillatorOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    @"type": ?enums.OscillatorType = null,
    frequency: ?f32 = null,
    detune: ?f32 = null,
    periodicWave: ?*runtime.Instance = null,
};
