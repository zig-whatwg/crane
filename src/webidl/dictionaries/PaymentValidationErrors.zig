//! WebIDL dictionary: PaymentValidationErrors
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PaymentValidationErrors = struct {
    payer: ?*const anyopaque = null,
    shippingAddress: ?*const anyopaque = null,
    @"error": ?runtime.DOMString = null,
    paymentMethod: ?*const anyopaque = null,
};
