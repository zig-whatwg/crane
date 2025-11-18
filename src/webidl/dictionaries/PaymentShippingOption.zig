//! WebIDL dictionary: PaymentShippingOption
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PaymentShippingOption = struct {
    id: runtime.DOMString,
    label: runtime.DOMString,
    amount: anyopaque,
    selected: ?bool = null,
};
