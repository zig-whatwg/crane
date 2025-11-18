//! WebIDL dictionary: WaveShaperOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const WaveShaperOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    curve: ?anyopaque = null,
    oversample: ?anyopaque = null,
};
