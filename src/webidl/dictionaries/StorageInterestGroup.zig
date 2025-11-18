//! WebIDL dictionary: StorageInterestGroup
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AuctionAdInterestGroup = @import("AuctionAdInterestGroup.zig").AuctionAdInterestGroup;

pub const StorageInterestGroup = struct {
    // Inherited from AuctionAdInterestGroup
    base: AuctionAdInterestGroup,

    joinCount: ?u64 = null,
    bidCount: ?u64 = null,
    prevWinsMs: ?anyopaque = null,
    joiningOrigin: ?runtime.DOMString = null,
    timeSinceGroupJoinedMs: ?i64 = null,
    lifetimeRemainingMs: ?i64 = null,
    timeSinceLastUpdateMs: ?i64 = null,
    timeUntilNextUpdateMs: ?i64 = null,
    estimatedSize: ?u64 = null,
};
