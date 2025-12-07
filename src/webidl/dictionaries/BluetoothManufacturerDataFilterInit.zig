//! WebIDL dictionary: BluetoothManufacturerDataFilterInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const BluetoothDataFilterInit = @import("BluetoothDataFilterInit.zig").BluetoothDataFilterInit;

pub const BluetoothManufacturerDataFilterInit = struct {
    // Inherited from BluetoothDataFilterInit
    base: BluetoothDataFilterInit,

    companyIdentifier: u16,
};
