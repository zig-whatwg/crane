//! WebIDL dictionary: PaymentDetailsUpdate
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PaymentDetailsBase = @import("PaymentDetailsBase.zig").PaymentDetailsBase;

pub const PaymentDetailsUpdate = struct {
    // Inherited from PaymentDetailsBase
    base: PaymentDetailsBase,

    error: ?runtime.DOMString = null,
    total: ?anyopaque = null,
    shippingAddressErrors: ?anyopaque = null,
    payerErrors: ?anyopaque = null,
    paymentMethodErrors: ?anyopaque = null,
};
