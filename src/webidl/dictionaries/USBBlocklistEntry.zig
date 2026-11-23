//! WebIDL dictionary: USBBlocklistEntry
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const USBBlocklistEntry = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    idVendor: u16,
    idProduct: u16,
    bcdDevice: u16,
};
