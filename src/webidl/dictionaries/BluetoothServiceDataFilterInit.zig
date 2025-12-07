//! WebIDL dictionary: BluetoothServiceDataFilterInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const BluetoothDataFilterInit = @import("BluetoothDataFilterInit.zig").BluetoothDataFilterInit;

pub const BluetoothServiceDataFilterInit = struct {
    // Inherited from BluetoothDataFilterInit
    base: BluetoothDataFilterInit,

    service: typedefs.BluetoothServiceUUID,
};
