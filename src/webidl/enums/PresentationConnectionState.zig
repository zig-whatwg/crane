//! WebIDL enum: PresentationConnectionState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const PresentationConnectionState = enum {
    _connecting_,
    _connected_,
    _closed_,
    _terminated_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "connecting", "connected", "closed", "terminated" };
};
