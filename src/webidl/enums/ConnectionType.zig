//! WebIDL enum: ConnectionType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const ConnectionType = enum {
    _bluetooth_,
    _cellular_,
    _ethernet_,
    _mixed_,
    _none_,
    _other_,
    _unknown_,
    _wifi_,
    _wimax_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "bluetooth", "cellular", "ethernet", "mixed", "none", "other", "unknown", "wifi", "wimax" };
};
