//! WebIDL dictionary: AllowedUSBDevice
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AllowedUSBDevice = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    vendorId: u8,
    productId: u8,
    serialNumber: ?runtime.DOMString = null,
};
