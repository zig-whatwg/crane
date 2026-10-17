//! WebIDL dictionary: RTCTrackEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const RTCTrackEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    receiver: *runtime.Instance,
    track: *runtime.Instance,
    streams: ?[]const *runtime.Instance = null,
    transceiver: *runtime.Instance,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "receiver", "RTCRtpReceiver" },
        .{ "track", "MediaStreamTrack" },
        .{ "streams", "MediaStream" },
        .{ "transceiver", "RTCRtpTransceiver" },
    };
};
