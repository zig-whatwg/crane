//! WebIDL dictionary: AuctionAd
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const AuctionAd = struct {
    renderURL: runtime.USVString,
    sizeGroup: ?runtime.USVString = null,
    metadata: ?runtime.JSValue = null,
    buyerReportingId: ?runtime.USVString = null,
    buyerAndSellerReportingId: ?runtime.USVString = null,
    selectableBuyerAndSellerReportingIds: ?[]const runtime.USVString = null,
    allowedReportingOrigins: ?[]const runtime.USVString = null,
    adRenderId: ?runtime.DOMString = null,
    creativeScanningMetadata: ?runtime.USVString = null,
};
