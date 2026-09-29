//! WebIDL dictionary: ReportResultBrowserSignals
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const ReportingBrowserSignals = @import("ReportingBrowserSignals.zig").ReportingBrowserSignals;

pub const ReportResultBrowserSignals = struct {
    // Inherited from ReportingBrowserSignals
    base: ReportingBrowserSignals,

    desirability: f64,
    topLevelSellerSignals: ?runtime.DOMString = null,
    modifiedBid: ?f64 = null,
    dataVersion: ?u32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "desirability", "modifiedBid" };
};
