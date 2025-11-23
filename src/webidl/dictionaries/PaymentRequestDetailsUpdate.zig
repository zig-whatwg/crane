//! WebIDL dictionary: PaymentRequestDetailsUpdate
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PaymentRequestDetailsUpdate = struct {
    @"error": ?runtime.DOMString = null,
    total: ?*const anyopaque = null,
    modifiers: ?*const anyopaque = null,
    shippingOptions: ?*const anyopaque = null,
    paymentMethodErrors: ?*const anyopaque = null,
    shippingAddressErrors: ?*const anyopaque = null,
};
