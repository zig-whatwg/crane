//! WebIDL dictionary: ItemDetails
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const PaymentCurrencyAmount = @import("PaymentCurrencyAmount.zig").PaymentCurrencyAmount;

pub const ItemDetails = struct {
    itemId: runtime.DOMString,
    title: runtime.DOMString,
    price: PaymentCurrencyAmount,
    @"type": ?enums.ItemType = null,
    description: ?runtime.DOMString = null,
    iconURLs: ?[]const runtime.DOMString = null,
    subscriptionPeriod: ?runtime.DOMString = null,
    freeTrialPeriod: ?runtime.DOMString = null,
    introductoryPrice: ?PaymentCurrencyAmount = null,
    introductoryPricePeriod: ?runtime.DOMString = null,
    introductoryPriceCycles: ?u64 = null,
};
