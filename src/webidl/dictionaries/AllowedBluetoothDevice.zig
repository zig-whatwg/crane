//! WebIDL dictionary: AllowedBluetoothDevice
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const AllowedBluetoothDevice = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    deviceId: runtime.DOMString,
    mayUseGATT: bool,
    allowedServices: runtime.JSValue,
    allowedManufacturerData: []const u16,
};
