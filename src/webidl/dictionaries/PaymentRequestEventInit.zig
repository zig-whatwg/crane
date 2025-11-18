//! WebIDL dictionary: PaymentRequestEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const PaymentRequestEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    topOrigin: ?runtime.DOMString = null,
    paymentRequestOrigin: ?runtime.DOMString = null,
    paymentRequestId: ?runtime.DOMString = null,
    methodData: ?anyopaque = null,
    total: ?anyopaque = null,
    modifiers: ?anyopaque = null,
    paymentOptions: ?anyopaque = null,
    shippingOptions: ?anyopaque = null,
};
