//! WebIDL dictionary: IIRFilterOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const IIRFilterOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    feedforward: anyopaque,
    feedback: anyopaque,
};
