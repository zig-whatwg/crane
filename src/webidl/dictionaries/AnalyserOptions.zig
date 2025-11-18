//! WebIDL dictionary: AnalyserOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const AnalyserOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    fftSize: ?u32 = null,
    maxDecibels: ?f64 = null,
    minDecibels: ?f64 = null,
    smoothingTimeConstant: ?f64 = null,
};
