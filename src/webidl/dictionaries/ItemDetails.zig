//! WebIDL dictionary: ItemDetails
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ItemDetails = struct {
    itemId: runtime.DOMString,
    title: runtime.DOMString,
    price: *const anyopaque,
    type: ?*const anyopaque = null,
    description: ?runtime.DOMString = null,
    iconURLs: ?*const anyopaque = null,
    subscriptionPeriod: ?runtime.DOMString = null,
    freeTrialPeriod: ?runtime.DOMString = null,
    introductoryPrice: ?*const anyopaque = null,
    introductoryPricePeriod: ?runtime.DOMString = null,
    introductoryPriceCycles: ?u64 = null,
};
