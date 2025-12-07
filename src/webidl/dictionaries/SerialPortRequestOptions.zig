//! WebIDL dictionary: SerialPortRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const SerialPortFilter = @import("SerialPortFilter.zig").SerialPortFilter;

pub const SerialPortRequestOptions = struct {
    filters: ?[]const SerialPortFilter = null,
    allowedBluetoothServiceClassIds: ?[]const typedefs.BluetoothServiceUUID = null,
};
