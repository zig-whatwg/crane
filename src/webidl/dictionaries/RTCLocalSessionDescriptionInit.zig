//! WebIDL dictionary: RTCLocalSessionDescriptionInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const RTCLocalSessionDescriptionInit = struct {
    @"type": ?enums.RTCSdpType = null,
    sdp: ?runtime.DOMString = null,
};
