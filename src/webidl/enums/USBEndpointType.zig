//! WebIDL enum: USBEndpointType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const USBEndpointType = enum {
    _bulk_,
    _interrupt_,
    _isochronous_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "bulk", "interrupt", "isochronous" };
};
