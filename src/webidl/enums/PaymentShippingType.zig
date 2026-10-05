//! WebIDL enum: PaymentShippingType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const PaymentShippingType = enum {
    _shipping_,
    _delivery_,
    _pickup_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "shipping", "delivery", "pickup" };
};
