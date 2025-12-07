//! WebIDL dictionary: HIDDeviceRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const HIDDeviceFilter = @import("HIDDeviceFilter.zig").HIDDeviceFilter;

pub const HIDDeviceRequestOptions = struct {
    filters: []const HIDDeviceFilter,
    exclusionFilters: ?[]const HIDDeviceFilter = null,
};
