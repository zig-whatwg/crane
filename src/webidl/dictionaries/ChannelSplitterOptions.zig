//! WebIDL dictionary: ChannelSplitterOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const ChannelSplitterOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    numberOfOutputs: ?u32 = null,
};
