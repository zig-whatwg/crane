//! WebIDL dictionary: AllowedBluetoothDevice
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AllowedBluetoothDevice = struct {
    deviceId: runtime.DOMString,
    mayUseGATT: bool,
    allowedServices: anyopaque,
    allowedManufacturerData: anyopaque,
};
