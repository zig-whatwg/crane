//! WebIDL dictionary: IIRFilterOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const IIRFilterOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    feedforward: []const f64,
    feedback: []const f64,
};
