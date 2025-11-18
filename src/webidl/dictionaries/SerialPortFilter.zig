//! WebIDL dictionary: SerialPortFilter
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const SerialPortFilter = struct {
    usbVendorId: ?u16 = null,
    usbProductId: ?u16 = null,
    bluetoothServiceClassId: ?anyopaque = null,
};
