//! WebIDL dictionary: BluetoothLEScanPermissionDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PermissionDescriptor = @import("PermissionDescriptor.zig").PermissionDescriptor;

pub const BluetoothLEScanPermissionDescriptor = struct {
    // Inherited from PermissionDescriptor
    base: PermissionDescriptor,

    filters: ?anyopaque = null,
    keepRepeatedDevices: ?bool = null,
    acceptAllAdvertisements: ?bool = null,
};
