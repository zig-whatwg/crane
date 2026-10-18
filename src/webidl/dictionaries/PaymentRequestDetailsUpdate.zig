//! WebIDL dictionary: PaymentRequestDetailsUpdate
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AddressErrors = @import("AddressErrors.zig").AddressErrors;
const PaymentDetailsModifier = @import("PaymentDetailsModifier.zig").PaymentDetailsModifier;
const PaymentCurrencyAmount = @import("PaymentCurrencyAmount.zig").PaymentCurrencyAmount;
const PaymentShippingOption = @import("PaymentShippingOption.zig").PaymentShippingOption;

pub const PaymentRequestDetailsUpdate = struct {
    @"error": ?runtime.DOMString = null,
    total: ?PaymentCurrencyAmount = null,
    modifiers: ?[]const PaymentDetailsModifier = null,
    shippingOptions: ?[]const PaymentShippingOption = null,
    paymentMethodErrors: ?runtime.JSValue = null,
    shippingAddressErrors: ?AddressErrors = null,

    /// WebIDL `object` members (or sequences of `object`): a value that is
    /// not an Object throws a TypeError when the dictionary is converted.
    pub const object_members = .{"paymentMethodErrors"};
};
