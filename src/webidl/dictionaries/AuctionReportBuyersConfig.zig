//! WebIDL dictionary: AuctionReportBuyersConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AuctionReportBuyersConfig = struct {
    bucket: runtime.JSValue,
    scale: f64,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"scale"};
};
