//! WebIDL enum: RTCPeerConnectionState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const RTCPeerConnectionState = enum {
    _closed_,
    _failed_,
    _disconnected_,
    _new_,
    _connecting_,
    _connected_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "closed", "failed", "disconnected", "new", "connecting", "connected" };
};
