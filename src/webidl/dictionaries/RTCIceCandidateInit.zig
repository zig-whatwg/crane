//! WebIDL dictionary: RTCIceCandidateInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const RTCIceCandidateInit = struct {
    candidate: ?runtime.DOMString = null,
    sdpMid: ?runtime.DOMString = null,
    sdpMLineIndex: ?u16 = null,
    usernameFragment: ?runtime.DOMString = null,
};
