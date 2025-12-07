//! WebIDL dictionary: PaymentItem
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const PaymentCurrencyAmount = @import("PaymentCurrencyAmount.zig").PaymentCurrencyAmount;

pub const PaymentItem = struct {
    label: runtime.DOMString,
    amount: PaymentCurrencyAmount,
    pending: ?bool = null,
};
