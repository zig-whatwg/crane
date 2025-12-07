//! WebIDL typedef: BluetoothServiceUUID
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const BluetoothServiceUUID = union(enum) {
    domstring: runtime.DOMString,
    ulong: u32,
};
