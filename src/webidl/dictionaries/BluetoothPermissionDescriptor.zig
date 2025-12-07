//! WebIDL dictionary: BluetoothPermissionDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const BluetoothLEScanFilterInit = @import("BluetoothLEScanFilterInit.zig").BluetoothLEScanFilterInit;
const PermissionDescriptor = @import("PermissionDescriptor.zig").PermissionDescriptor;

pub const BluetoothPermissionDescriptor = struct {
    // Inherited from PermissionDescriptor
    base: PermissionDescriptor,

    deviceId: ?runtime.DOMString = null,
    filters: ?[]const BluetoothLEScanFilterInit = null,
    optionalServices: ?[]const typedefs.BluetoothServiceUUID = null,
    optionalManufacturerData: ?[]const u16 = null,
    acceptAllDevices: ?bool = null,
};
