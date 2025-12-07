//! WebIDL dictionary: USBPermissionDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const USBDeviceFilter = @import("USBDeviceFilter.zig").USBDeviceFilter;
const PermissionDescriptor = @import("PermissionDescriptor.zig").PermissionDescriptor;

pub const USBPermissionDescriptor = struct {
    // Inherited from PermissionDescriptor
    base: PermissionDescriptor,

    filters: ?[]const USBDeviceFilter = null,
    exclusionFilters: ?[]const USBDeviceFilter = null,
};
