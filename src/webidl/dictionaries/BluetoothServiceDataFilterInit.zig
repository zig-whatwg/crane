//! WebIDL dictionary: BluetoothServiceDataFilterInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const BluetoothDataFilterInit = @import("BluetoothDataFilterInit.zig").BluetoothDataFilterInit;

pub const BluetoothServiceDataFilterInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from BluetoothDataFilterInit
    base: BluetoothDataFilterInit,

    service: typedefs.BluetoothServiceUUID,
};
