//! WebIDL dictionary: BluetoothLEScanFilterInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const BluetoothManufacturerDataFilterInit = @import("BluetoothManufacturerDataFilterInit.zig").BluetoothManufacturerDataFilterInit;
const BluetoothServiceDataFilterInit = @import("BluetoothServiceDataFilterInit.zig").BluetoothServiceDataFilterInit;

pub const BluetoothLEScanFilterInit = struct {
    services: ?[]const typedefs.BluetoothServiceUUID = null,
    name: ?runtime.DOMString = null,
    namePrefix: ?runtime.DOMString = null,
    manufacturerData: ?[]const BluetoothManufacturerDataFilterInit = null,
    serviceData: ?[]const BluetoothServiceDataFilterInit = null,
};
