//! WebIDL enum: USBRecipient
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const USBRecipient = enum {
    _device_,
    _interface_,
    _endpoint_,
    _other_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "device", "interface", "endpoint", "other" };
};
