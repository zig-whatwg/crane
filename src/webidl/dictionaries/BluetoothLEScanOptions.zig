//! WebIDL dictionary: BluetoothLEScanOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const BluetoothLEScanFilterInit = @import("BluetoothLEScanFilterInit.zig").BluetoothLEScanFilterInit;

pub const BluetoothLEScanOptions = struct {
    filters: ?[]const BluetoothLEScanFilterInit = null,
    keepRepeatedDevices: ?bool = null,
    acceptAllAdvertisements: ?bool = null,
};
