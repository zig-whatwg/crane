//! WebIDL dictionary: AuctionAdInterestGroup
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const ProtectedAudiencePrivateAggregationConfig = @import("ProtectedAudiencePrivateAggregationConfig.zig").ProtectedAudiencePrivateAggregationConfig;
const GenerateBidInterestGroup = @import("GenerateBidInterestGroup.zig").GenerateBidInterestGroup;

pub const AuctionAdInterestGroup = struct {
    // Inherited from GenerateBidInterestGroup
    base: GenerateBidInterestGroup,

    priority: ?f64 = null,
    prioritySignalsOverrides: ?[]const struct { key: runtime.DOMString, value: f64 } = null,
    lifetimeMs: f64,
    additionalBidKey: ?runtime.DOMString = null,
    privateAggregationConfig: ?ProtectedAudiencePrivateAggregationConfig = null,
};
