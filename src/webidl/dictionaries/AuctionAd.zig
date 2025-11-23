//! WebIDL dictionary: AuctionAd
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AuctionAd = struct {
    renderURL: runtime.USVString,
    sizeGroup: ?runtime.USVString = null,
    metadata: ?*const anyopaque = null,
    buyerReportingId: ?runtime.USVString = null,
    buyerAndSellerReportingId: ?runtime.USVString = null,
    selectableBuyerAndSellerReportingIds: ?*const anyopaque = null,
    allowedReportingOrigins: ?*const anyopaque = null,
    adRenderId: ?runtime.DOMString = null,
    creativeScanningMetadata: ?runtime.USVString = null,
};
