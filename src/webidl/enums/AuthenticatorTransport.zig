//! WebIDL enum: AuthenticatorTransport
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const AuthenticatorTransport = enum {
    _usb_,
    _nfc_,
    _ble_,
    _smart_card_,
    _hybrid_,
    _internal_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "usb", "nfc", "ble", "smart-card", "hybrid", "internal" };
};
