//! WebIDL dictionary: PaymentOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PaymentOptions = struct {
    requestPayerName: ?bool = null,
    requestBillingAddress: ?bool = null,
    requestPayerEmail: ?bool = null,
    requestPayerPhone: ?bool = null,
    requestShipping: ?bool = null,
    shippingType: ?anyopaque = null,
};
