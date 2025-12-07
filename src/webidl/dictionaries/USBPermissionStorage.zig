//! WebIDL dictionary: USBPermissionStorage
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AllowedUSBDevice = @import("AllowedUSBDevice.zig").AllowedUSBDevice;

pub const USBPermissionStorage = struct {
    allowedDevices: ?[]const AllowedUSBDevice = null,
};
