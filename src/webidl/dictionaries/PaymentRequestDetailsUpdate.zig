//! WebIDL dictionary: PaymentRequestDetailsUpdate
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const AddressErrors = @import("AddressErrors.zig").AddressErrors;
const PaymentDetailsModifier = @import("PaymentDetailsModifier.zig").PaymentDetailsModifier;
const PaymentCurrencyAmount = @import("PaymentCurrencyAmount.zig").PaymentCurrencyAmount;
const PaymentShippingOption = @import("PaymentShippingOption.zig").PaymentShippingOption;

pub const PaymentRequestDetailsUpdate = struct {
    @"error": ?runtime.DOMString = null,
    total: ?PaymentCurrencyAmount = null,
    modifiers: ?[]const PaymentDetailsModifier = null,
    shippingOptions: ?[]const PaymentShippingOption = null,
    paymentMethodErrors: ?v8.JSValue = null,
    shippingAddressErrors: ?AddressErrors = null,
};
