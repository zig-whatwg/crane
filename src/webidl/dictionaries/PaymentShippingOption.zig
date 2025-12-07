//! WebIDL dictionary: PaymentShippingOption
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const PaymentCurrencyAmount = @import("PaymentCurrencyAmount.zig").PaymentCurrencyAmount;

pub const PaymentShippingOption = struct {
    id: runtime.DOMString,
    label: runtime.DOMString,
    amount: PaymentCurrencyAmount,
    selected: ?bool = null,
};
