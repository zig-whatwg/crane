//! WebIDL dictionary: MediaStreamTrackProcessorInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MediaStreamTrackProcessorInit = struct {
    track: *runtime.Instance,
    maxBufferSize: ?u16 = null,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"maxBufferSize"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "track", "MediaStreamTrack" },
    };
};
