//! WebIDL dictionary: RequestDeviceOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const BluetoothLEScanFilterInit = @import("BluetoothLEScanFilterInit.zig").BluetoothLEScanFilterInit;

pub const RequestDeviceOptions = struct {
    filters: ?[]const BluetoothLEScanFilterInit = null,
    exclusionFilters: ?[]const BluetoothLEScanFilterInit = null,
    optionalServices: ?[]const typedefs.BluetoothServiceUUID = null,
    optionalManufacturerData: ?[]const u16 = null,
    acceptAllDevices: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "optionalServices", .empty_sequence },
        .{ "optionalManufacturerData", .empty_sequence },
        .{ "acceptAllDevices", .{ .boolean = false } },
    };
};
