//! WebIDL dictionary: BluetoothPermissionStorage
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AllowedBluetoothDevice = @import("AllowedBluetoothDevice.zig").AllowedBluetoothDevice;

pub const BluetoothPermissionStorage = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    allowedDevices: []const AllowedBluetoothDevice,
};
