//! WebIDL dictionary: SerialPortInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const SerialPortInfo = struct {
    usbVendorId: ?u16 = null,
    usbProductId: ?u16 = null,
    bluetoothServiceClassId: ?typedefs.BluetoothServiceUUID = null,
};
