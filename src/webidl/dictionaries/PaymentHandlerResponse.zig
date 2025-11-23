//! WebIDL dictionary: PaymentHandlerResponse
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PaymentHandlerResponse = struct {
    methodName: ?runtime.DOMString = null,
    details: ?*const anyopaque = null,
    payerName: ?runtime.DOMString = null,
    payerEmail: ?runtime.DOMString = null,
    payerPhone: ?runtime.DOMString = null,
    shippingAddress: ?*const anyopaque = null,
    shippingOption: ?runtime.DOMString = null,
};
