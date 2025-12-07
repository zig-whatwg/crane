//! WebIDL dictionary: PaymentOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const PaymentOptions = struct {
    requestPayerName: ?bool = null,
    requestBillingAddress: ?bool = null,
    requestPayerEmail: ?bool = null,
    requestPayerPhone: ?bool = null,
    requestShipping: ?bool = null,
    shippingType: ?enums.PaymentShippingType = null,
};
