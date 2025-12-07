//! WebIDL dictionary: BluetoothPermissionStorage
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AllowedBluetoothDevice = @import("AllowedBluetoothDevice.zig").AllowedBluetoothDevice;

pub const BluetoothPermissionStorage = struct {
    allowedDevices: []const AllowedBluetoothDevice,
};
