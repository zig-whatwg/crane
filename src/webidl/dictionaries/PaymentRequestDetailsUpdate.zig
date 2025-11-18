//! WebIDL dictionary: PaymentRequestDetailsUpdate
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PaymentRequestDetailsUpdate = struct {
    error: ?runtime.DOMString = null,
    total: ?anyopaque = null,
    modifiers: ?anyopaque = null,
    shippingOptions: ?anyopaque = null,
    paymentMethodErrors: ?anyopaque = null,
    shippingAddressErrors: ?anyopaque = null,
};
