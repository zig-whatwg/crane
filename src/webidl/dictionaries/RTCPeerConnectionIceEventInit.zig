//! WebIDL dictionary: RTCPeerConnectionIceEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const RTCPeerConnectionIceEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    candidate: ?*const anyopaque = null,
    url: ?runtime.USVString = null,
};
