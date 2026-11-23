//! WebIDL dictionary: HIDDeviceFilter
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const HIDDeviceFilter = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    vendorId: ?u32 = null,
    productId: ?u16 = null,
    usagePage: ?u16 = null,
    usage: ?u16 = null,
};
