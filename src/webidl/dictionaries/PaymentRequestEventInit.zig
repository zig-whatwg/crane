//! WebIDL dictionary: PaymentRequestEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const PaymentRequestEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    topOrigin: ?runtime.USVString = null,
    paymentRequestOrigin: ?runtime.USVString = null,
    paymentRequestId: ?runtime.DOMString = null,
    methodData: ?*const anyopaque = null,
    total: ?*const anyopaque = null,
    modifiers: ?*const anyopaque = null,
    paymentOptions: ?*const anyopaque = null,
    shippingOptions: ?*const anyopaque = null,
};
