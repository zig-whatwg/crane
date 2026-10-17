//! WebIDL dictionary: RTCSessionDescriptionInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const RTCSessionDescriptionInit = struct {
    type: enums.RTCSdpType,
    sdp: ?runtime.DOMString = null,
};
