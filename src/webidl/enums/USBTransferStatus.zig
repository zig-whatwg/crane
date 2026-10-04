//! WebIDL enum: USBTransferStatus
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const USBTransferStatus = enum {
    _ok_,
    _stall_,
    _babble_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "ok", "stall", "babble" };
};
