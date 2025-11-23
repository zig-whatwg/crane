//! WebIDL dictionary: USBDeviceFilter
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const USBDeviceFilter = struct {
    vendorId: ?u16 = null,
    productId: ?u16 = null,
    classCode: ?u8 = null,
    subclassCode: ?u8 = null,
    protocolCode: ?u8 = null,
    serialNumber: ?runtime.DOMString = null,
};
