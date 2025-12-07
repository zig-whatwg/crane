//! WebIDL typedef: BluetoothCharacteristicUUID
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");

pub const BluetoothCharacteristicUUID = union(enum) {
    domstring: runtime.DOMString,
    ulong: u32,
};
