//! WebIDL dictionary: PaymentValidationErrors
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PaymentValidationErrors = struct {
    payer: ?anyopaque = null,
    shippingAddress: ?anyopaque = null,
    error: ?runtime.DOMString = null,
    paymentMethod: ?anyopaque = null,
};
