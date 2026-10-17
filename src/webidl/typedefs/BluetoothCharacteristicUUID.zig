//! WebIDL typedef: BluetoothCharacteristicUUID
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const BluetoothCharacteristicUUID = union(enum) {
    domstring: runtime.DOMString,
    ulong: u32,
};
