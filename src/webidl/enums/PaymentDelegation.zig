//! WebIDL enum: PaymentDelegation
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const PaymentDelegation = enum {
    _shippingAddress_,
    _payerName_,
    _payerPhone_,
    _payerEmail_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "shippingAddress", "payerName", "payerPhone", "payerEmail" };
};
