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
    outputChannelCount: ?[]const u32 = null,
    parameterData: ?[]const struct { key: runtime.DOMString, value: f64 } = null,
    processorOptions: ?runtime.JSValue = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "numberOfInputs", .{ .number = 1 } },
        .{ "numberOfOutputs", .{ .number = 1 } },
    };
};
