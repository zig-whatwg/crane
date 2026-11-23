//! WebIDL dictionary: HIDDeviceRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const HIDDeviceFilter = @import("HIDDeviceFilter.zig").HIDDeviceFilter;

pub const HIDDeviceRequestOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    filters: []const HIDDeviceFilter,
    exclusionFilters: ?[]const HIDDeviceFilter = null,
};
