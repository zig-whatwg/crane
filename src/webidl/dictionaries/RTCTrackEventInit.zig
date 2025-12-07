//! WebIDL dictionary: RTCTrackEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const EventInit = @import("EventInit.zig").EventInit;

pub const RTCTrackEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    receiver: *runtime.Instance,
    track: *runtime.Instance,
    streams: ?[]const *runtime.Instance = null,
    transceiver: *runtime.Instance,
};
