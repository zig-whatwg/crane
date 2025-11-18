//! WebIDL dictionary: PaymentItem
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PaymentItem = struct {
    label: runtime.DOMString,
    amount: anyopaque,
    pending: ?bool = null,
};
