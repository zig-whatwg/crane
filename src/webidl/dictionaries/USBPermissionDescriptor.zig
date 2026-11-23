//! WebIDL dictionary: USBPermissionDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const USBDeviceFilter = @import("USBDeviceFilter.zig").USBDeviceFilter;
const PermissionDescriptor = @import("PermissionDescriptor.zig").PermissionDescriptor;

pub const USBPermissionDescriptor = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from PermissionDescriptor
    base: PermissionDescriptor,

    filters: ?[]const USBDeviceFilter = null,
    exclusionFilters: ?[]const USBDeviceFilter = null,
};
