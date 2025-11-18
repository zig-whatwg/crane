//! WebIDL dictionary: AudioWorkletNodeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const AudioWorkletNodeOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    numberOfInputs: ?u32 = null,
    numberOfOutputs: ?u32 = null,
    outputChannelCount: ?anyopaque = null,
    parameterData: ?anyopaque = null,
    processorOptions: ?anyopaque = null,
};
