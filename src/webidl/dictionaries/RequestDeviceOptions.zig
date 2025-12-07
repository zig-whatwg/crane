//! WebIDL dictionary: RequestDeviceOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const BluetoothLEScanFilterInit = @import("BluetoothLEScanFilterInit.zig").BluetoothLEScanFilterInit;

pub const RequestDeviceOptions = struct {
    filters: ?[]const BluetoothLEScanFilterInit = null,
    exclusionFilters: ?[]const BluetoothLEScanFilterInit = null,
    optionalServices: ?[]const typedefs.BluetoothServiceUUID = null,
    optionalManufacturerData: ?[]const u16 = null,
    acceptAllDevices: ?bool = null,
};
