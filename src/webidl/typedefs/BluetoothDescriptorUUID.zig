//! WebIDL typedef: BluetoothDescriptorUUID
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const BluetoothDescriptorUUID = union(enum) {
    domstring: runtime.DOMString,
    ulong: u32,
};
