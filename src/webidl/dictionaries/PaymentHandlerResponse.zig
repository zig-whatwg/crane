//! WebIDL dictionary: PaymentHandlerResponse
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const PaymentHandlerResponse = struct {
    methodName: ?runtime.DOMString = null,
    details: ?runtime.JSValue = null,
    payerName: ?runtime.DOMString = null,
    payerEmail: ?runtime.DOMString = null,
    payerPhone: ?runtime.DOMString = null,
    shippingAddress: ?runtime.JSValue = null,
    shippingOption: ?runtime.DOMString = null,
};
