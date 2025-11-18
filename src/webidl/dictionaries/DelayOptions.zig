//! WebIDL dictionary: DelayOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const DelayOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    maxDelayTime: ?f64 = null,
    delayTime: ?f64 = null,
};
