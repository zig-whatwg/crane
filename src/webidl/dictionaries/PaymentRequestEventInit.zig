//! WebIDL dictionary: PaymentRequestEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const PaymentDetailsModifier = @import("PaymentDetailsModifier.zig").PaymentDetailsModifier;
const PaymentMethodData = @import("PaymentMethodData.zig").PaymentMethodData;
const PaymentCurrencyAmount = @import("PaymentCurrencyAmount.zig").PaymentCurrencyAmount;
const PaymentOptions = @import("PaymentOptions.zig").PaymentOptions;
const PaymentShippingOption = @import("PaymentShippingOption.zig").PaymentShippingOption;
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const PaymentRequestEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    topOrigin: ?runtime.USVString = null,
    paymentRequestOrigin: ?runtime.USVString = null,
    paymentRequestId: ?runtime.DOMString = null,
    methodData: ?[]const PaymentMethodData = null,
    total: ?PaymentCurrencyAmount = null,
    modifiers: ?[]const PaymentDetailsModifier = null,
    paymentOptions: ?PaymentOptions = null,
    shippingOptions: ?[]const PaymentShippingOption = null,
};
