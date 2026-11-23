//! WebIDL dictionary: SerialPortFilter
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const SerialPortFilter = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    usbVendorId: ?u16 = null,
    usbProductId: ?u16 = null,
    bluetoothServiceClassId: ?typedefs.BluetoothServiceUUID = null,
};
