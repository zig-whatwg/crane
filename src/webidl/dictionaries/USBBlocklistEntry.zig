//! WebIDL dictionary: USBBlocklistEntry
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const USBBlocklistEntry = struct {
    idVendor: u16,
    idProduct: u16,
    bcdDevice: u16,
};
