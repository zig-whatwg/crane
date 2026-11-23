//! WebIDL dictionary: BluetoothLEScanFilterInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const BluetoothManufacturerDataFilterInit = @import("BluetoothManufacturerDataFilterInit.zig").BluetoothManufacturerDataFilterInit;
const BluetoothServiceDataFilterInit = @import("BluetoothServiceDataFilterInit.zig").BluetoothServiceDataFilterInit;

pub const BluetoothLEScanFilterInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    services: ?[]const typedefs.BluetoothServiceUUID = null,
    name: ?runtime.DOMString = null,
    namePrefix: ?runtime.DOMString = null,
    manufacturerData: ?[]const BluetoothManufacturerDataFilterInit = null,
    serviceData: ?[]const BluetoothServiceDataFilterInit = null,
};
