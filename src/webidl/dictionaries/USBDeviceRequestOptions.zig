//! WebIDL dictionary: USBDeviceRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const USBDeviceFilter = @import("USBDeviceFilter.zig").USBDeviceFilter;

pub const USBDeviceRequestOptions = struct {
    filters: []const USBDeviceFilter,
    exclusionFilters: ?[]const USBDeviceFilter = null,
};
