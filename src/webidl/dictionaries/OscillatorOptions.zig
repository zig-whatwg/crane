//! WebIDL dictionary: OscillatorOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const OscillatorOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    type: ?enums.OscillatorType = null,
    frequency: ?f32 = null,
    detune: ?f32 = null,
    periodicWave: ?*runtime.Instance = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "frequency", "detune" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "type", .{ .string = "sine" } },
        .{ "frequency", .{ .number = 440 } },
        .{ "detune", .{ .number = 0 } },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "periodicWave", "PeriodicWave" },
    };
};
