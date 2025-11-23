//! WebIDL dictionary: RequestDeviceOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RequestDeviceOptions = struct {
    filters: ?*const anyopaque = null,
    exclusionFilters: ?*const anyopaque = null,
    optionalServices: ?*const anyopaque = null,
    optionalManufacturerData: ?*const anyopaque = null,
    acceptAllDevices: ?bool = null,
};
