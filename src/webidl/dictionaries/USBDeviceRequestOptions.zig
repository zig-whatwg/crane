//! WebIDL dictionary: USBDeviceRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const USBDeviceFilter = @import("USBDeviceFilter.zig").USBDeviceFilter;

pub const USBDeviceRequestOptions = struct {
    filters: []const USBDeviceFilter,
    exclusionFilters: ?[]const USBDeviceFilter = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "exclusionFilters", .empty_sequence },
    };
};
