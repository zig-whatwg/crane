//! WebIDL dictionary: ChannelMergerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const ChannelMergerOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    numberOfInputs: ?u32 = null,
};
