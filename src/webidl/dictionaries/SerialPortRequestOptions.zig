//! WebIDL dictionary: SerialPortRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const SerialPortFilter = @import("SerialPortFilter.zig").SerialPortFilter;

pub const SerialPortRequestOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    filters: ?[]const SerialPortFilter = null,
    allowedBluetoothServiceClassIds: ?[]const typedefs.BluetoothServiceUUID = null,
};
