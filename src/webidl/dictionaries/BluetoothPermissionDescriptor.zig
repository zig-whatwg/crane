//! WebIDL dictionary: BluetoothPermissionDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PermissionDescriptor = @import("PermissionDescriptor.zig").PermissionDescriptor;

pub const BluetoothPermissionDescriptor = struct {
    // Inherited from PermissionDescriptor
    base: PermissionDescriptor,

    deviceId: ?runtime.DOMString = null,
    filters: ?*const anyopaque = null,
    optionalServices: ?*const anyopaque = null,
    optionalManufacturerData: ?*const anyopaque = null,
    acceptAllDevices: ?bool = null,
};
