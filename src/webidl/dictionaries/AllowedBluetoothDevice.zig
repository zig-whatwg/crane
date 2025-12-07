//! WebIDL dictionary: AllowedBluetoothDevice
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const AllowedBluetoothDevice = struct {
    deviceId: runtime.DOMString,
    mayUseGATT: bool,
    allowedServices: *const anyopaque,
    allowedManufacturerData: []const u16,
};
