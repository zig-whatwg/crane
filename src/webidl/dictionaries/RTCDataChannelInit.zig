//! WebIDL dictionary: RTCDataChannelInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCDataChannelInit = struct {
    ordered: ?bool = null,
    maxPacketLifeTime: ?u16 = null,
    maxRetransmits: ?u16 = null,
    protocol: ?runtime.DOMString = null,
    negotiated: ?bool = null,
    id: ?u16 = null,
};
