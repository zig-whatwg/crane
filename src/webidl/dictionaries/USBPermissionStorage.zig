//! WebIDL dictionary: USBPermissionStorage
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AllowedUSBDevice = @import("AllowedUSBDevice.zig").AllowedUSBDevice;

pub const USBPermissionStorage = struct {
    allowedDevices: ?[]const AllowedUSBDevice = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "allowedDevices", .empty_sequence },
    };
};
