//! WebIDL dictionary: AllowedBluetoothDevice
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const AllowedBluetoothDevice = struct {
    deviceId: runtime.DOMString,
    mayUseGATT: bool,
    allowedServices: runtime.JSValue,
    allowedManufacturerData: []const u16,
};
