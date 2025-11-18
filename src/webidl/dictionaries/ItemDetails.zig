//! WebIDL dictionary: ItemDetails
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ItemDetails = struct {
    itemId: runtime.DOMString,
    title: runtime.DOMString,
    price: anyopaque,
    type: ?anyopaque = null,
    description: ?runtime.DOMString = null,
    iconURLs: ?anyopaque = null,
    subscriptionPeriod: ?runtime.DOMString = null,
    freeTrialPeriod: ?runtime.DOMString = null,
    introductoryPrice: ?anyopaque = null,
    introductoryPricePeriod: ?runtime.DOMString = null,
    introductoryPriceCycles: ?u64 = null,
};
