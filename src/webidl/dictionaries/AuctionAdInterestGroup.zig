//! WebIDL dictionary: AuctionAdInterestGroup
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GenerateBidInterestGroup = @import("GenerateBidInterestGroup.zig").GenerateBidInterestGroup;

pub const AuctionAdInterestGroup = struct {
    // Inherited from GenerateBidInterestGroup
    base: GenerateBidInterestGroup,

    priority: ?f64 = null,
    prioritySignalsOverrides: ?anyopaque = null,
    lifetimeMs: f64,
    additionalBidKey: ?runtime.DOMString = null,
    privateAggregationConfig: ?anyopaque = null,
};
