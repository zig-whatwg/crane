//! WebIDL dictionary: BluetoothPermissionDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PermissionDescriptor = @import("PermissionDescriptor.zig").PermissionDescriptor;

pub const BluetoothPermissionDescriptor = struct {
    // Inherited from PermissionDescriptor
    base: PermissionDescriptor,

    deviceId: ?runtime.DOMString = null,
    filters: ?anyopaque = null,
    optionalServices: ?anyopaque = null,
    optionalManufacturerData: ?anyopaque = null,
    acceptAllDevices: ?bool = null,
};
