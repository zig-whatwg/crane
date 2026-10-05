//! WebIDL enum: FenceReportingDestination
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const FenceReportingDestination = enum {
    _buyer_,
    _seller_,
    _component_seller_,
    _direct_seller_,
    _shared_storage_select_url_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "buyer", "seller", "component-seller", "direct-seller", "shared-storage-select-url" };
};
