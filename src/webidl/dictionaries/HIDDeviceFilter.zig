//! WebIDL dictionary: HIDDeviceFilter
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const HIDDeviceFilter = struct {
    vendorId: ?u32 = null,
    productId: ?u16 = null,
    usagePage: ?u16 = null,
    usage: ?u16 = null,
};
