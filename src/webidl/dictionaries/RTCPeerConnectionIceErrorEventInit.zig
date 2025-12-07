//! WebIDL dictionary: RTCPeerConnectionIceErrorEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const RTCPeerConnectionIceErrorEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    address: ?runtime.DOMString = null,
    port: ?u16 = null,
    url: ?runtime.USVString = null,
    errorCode: u16,
    errorText: ?runtime.USVString = null,
};
