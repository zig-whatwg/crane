//! WebIDL dictionary: AllowedUSBDevice
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const AllowedUSBDevice = struct {
    vendorId: u8,
    productId: u8,
    serialNumber: ?runtime.DOMString = null,
};
