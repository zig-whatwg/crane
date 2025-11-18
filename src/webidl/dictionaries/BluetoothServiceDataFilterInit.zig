//! WebIDL dictionary: BluetoothServiceDataFilterInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const BluetoothDataFilterInit = @import("BluetoothDataFilterInit.zig").BluetoothDataFilterInit;

pub const BluetoothServiceDataFilterInit = struct {
    // Inherited from BluetoothDataFilterInit
    base: BluetoothDataFilterInit,

    service: anyopaque,
};
