//! WebIDL dictionary: BluetoothLEScanPermissionDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const BluetoothLEScanFilterInit = @import("BluetoothLEScanFilterInit.zig").BluetoothLEScanFilterInit;
const PermissionDescriptor = @import("PermissionDescriptor.zig").PermissionDescriptor;

pub const BluetoothLEScanPermissionDescriptor = struct {
    // Inherited from PermissionDescriptor
    base: PermissionDescriptor,

    filters: ?[]const BluetoothLEScanFilterInit = null,
    keepRepeatedDevices: ?bool = null,
    acceptAllAdvertisements: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "keepRepeatedDevices", .{ .boolean = false } },
        .{ "acceptAllAdvertisements", .{ .boolean = false } },
    };
};
