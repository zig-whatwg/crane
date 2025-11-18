//! WebIDL dictionary: PaymentHandlerResponse
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PaymentHandlerResponse = struct {
    methodName: ?runtime.DOMString = null,
    details: ?anyopaque = null,
    payerName: ?anyopaque = null,
    payerEmail: ?anyopaque = null,
    payerPhone: ?anyopaque = null,
    shippingAddress: ?anyopaque = null,
    shippingOption: ?anyopaque = null,
};
