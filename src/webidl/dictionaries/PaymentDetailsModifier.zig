//! WebIDL dictionary: PaymentDetailsModifier
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const PaymentItem = @import("PaymentItem.zig").PaymentItem;

pub const PaymentDetailsModifier = struct {
    supportedMethods: runtime.DOMString,
    total: ?PaymentItem = null,
    additionalDisplayItems: ?[]const PaymentItem = null,
    data: ?v8.JSValue = null,
};
