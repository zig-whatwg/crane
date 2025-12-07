//! WebIDL dictionary: StorageInterestGroup
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const AuctionAdInterestGroup = @import("AuctionAdInterestGroup.zig").AuctionAdInterestGroup;

pub const StorageInterestGroup = struct {
    // Inherited from AuctionAdInterestGroup
    base: AuctionAdInterestGroup,

    joinCount: ?u64 = null,
    bidCount: ?u64 = null,
    prevWinsMs: ?[]const typedefs.PreviousWin = null,
    joiningOrigin: ?runtime.USVString = null,
    timeSinceGroupJoinedMs: ?i64 = null,
    lifetimeRemainingMs: ?i64 = null,
    timeSinceLastUpdateMs: ?i64 = null,
    timeUntilNextUpdateMs: ?i64 = null,
    estimatedSize: ?u64 = null,
};
