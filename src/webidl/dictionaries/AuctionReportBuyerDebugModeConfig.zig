//! WebIDL dictionary: AuctionReportBuyerDebugModeConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AuctionReportBuyerDebugModeConfig = struct {
    enabled: ?bool = null,
    debugKey: ?runtime.JSValue = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"debugKey"};
};
