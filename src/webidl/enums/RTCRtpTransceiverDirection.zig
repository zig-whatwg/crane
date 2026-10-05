//! WebIDL enum: RTCRtpTransceiverDirection
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const RTCRtpTransceiverDirection = enum {
    _sendrecv_,
    _sendonly_,
    _recvonly_,
    _inactive_,
    _stopped_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "sendrecv", "sendonly", "recvonly", "inactive", "stopped" };
};
