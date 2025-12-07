//! WebIDL dictionary: AudioWorkletNodeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const AudioWorkletNodeOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    numberOfInputs: ?u32 = null,
    numberOfOutputs: ?u32 = null,
    outputChannelCount: ?[]const u32 = null,
    parameterData: ?[]const struct { key: runtime.DOMString, value: f64 } = null,
    processorOptions: ?v8.JSValue = null,
};
