//! WebIDL dictionary: PaymentDetailsBase
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const PaymentDetailsModifier = @import("PaymentDetailsModifier.zig").PaymentDetailsModifier;
const PaymentItem = @import("PaymentItem.zig").PaymentItem;
const PaymentShippingOption = @import("PaymentShippingOption.zig").PaymentShippingOption;

pub const PaymentDetailsBase = struct {
    displayItems: ?[]const PaymentItem = null,
    shippingOptions: ?[]const PaymentShippingOption = null,
    modifiers: ?[]const PaymentDetailsModifier = null,
};
