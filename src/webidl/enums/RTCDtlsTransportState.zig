//! WebIDL enum: RTCDtlsTransportState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const RTCDtlsTransportState = enum {
    _new_,
    _connecting_,
    _connected_,
    _closed_,
    _failed_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "new", "connecting", "connected", "closed", "failed" };
};
