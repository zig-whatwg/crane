//! WebIDL dictionary: RTCPeerConnectionIceErrorEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const RTCPeerConnectionIceErrorEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    address: ?anyopaque = null,
    port: ?anyopaque = null,
    url: ?runtime.DOMString = null,
    errorCode: u16,
    errorText: ?runtime.DOMString = null,
};
