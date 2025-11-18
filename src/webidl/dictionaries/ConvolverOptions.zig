//! WebIDL dictionary: ConvolverOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const ConvolverOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    buffer: ?anyopaque = null,
    disableNormalization: ?bool = null,
};
