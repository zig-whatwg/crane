//! WebIDL dictionary: RTCIceCandidateInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCIceCandidateInit = struct {
    candidate: ?runtime.DOMString = null,
    sdpMid: ?runtime.DOMString = null,
    sdpMLineIndex: ?u16 = null,
    usernameFragment: ?runtime.DOMString = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "sdpMid", "sdpMLineIndex", "usernameFragment" };
};
