//! WebIDL dictionary: PaymentDetailsBase
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PaymentDetailsModifier = @import("PaymentDetailsModifier.zig").PaymentDetailsModifier;
const PaymentItem = @import("PaymentItem.zig").PaymentItem;
const PaymentShippingOption = @import("PaymentShippingOption.zig").PaymentShippingOption;

pub const PaymentDetailsBase = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    displayItems: ?[]const PaymentItem = null,
    shippingOptions: ?[]const PaymentShippingOption = null,
    modifiers: ?[]const PaymentDetailsModifier = null,
};
