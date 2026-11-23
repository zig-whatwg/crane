//! WebIDL dictionary: BluetoothLEScanOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const BluetoothLEScanFilterInit = @import("BluetoothLEScanFilterInit.zig").BluetoothLEScanFilterInit;

pub const BluetoothLEScanOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
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
