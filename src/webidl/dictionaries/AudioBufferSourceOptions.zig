//! WebIDL dictionary: AudioBufferSourceOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AudioBufferSourceOptions = struct {
    buffer: ?*runtime.Instance = null,
    detune: ?f32 = null,
    loop: ?bool = null,
    loopEnd: ?f64 = null,
    loopStart: ?f64 = null,
    playbackRate: ?f32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "detune", "loopEnd", "loopStart", "playbackRate" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "detune", .{ .number = 0 } },
        .{ "loop", .{ .boolean = false } },
        .{ "loopEnd", .{ .number = 0 } },
        .{ "loopStart", .{ .number = 0 } },
        .{ "playbackRate", .{ .number = 1 } },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"buffer"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "buffer", "AudioBuffer" },
    };
};
