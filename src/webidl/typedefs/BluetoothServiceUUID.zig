//! WebIDL typedef: BluetoothServiceUUID
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const BluetoothServiceUUID = union(enum) {
    domstring: runtime.DOMString,
    ulong: u32,
};
