//! WebIDL dictionary: RTCSessionDescriptionInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const RTCSessionDescriptionInit = struct {
    @"type": enums.RTCSdpType,
    sdp: ?runtime.DOMString = null,
};
