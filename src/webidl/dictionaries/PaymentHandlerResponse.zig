//! WebIDL dictionary: PaymentHandlerResponse
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const PaymentHandlerResponse = struct {
    methodName: ?runtime.DOMString = null,
    details: ?v8.JSValue = null,
    payerName: ?runtime.DOMString = null,
    payerEmail: ?runtime.DOMString = null,
    payerPhone: ?runtime.DOMString = null,
    shippingAddress: ?*const anyopaque = null,
    shippingOption: ?runtime.DOMString = null,
};
