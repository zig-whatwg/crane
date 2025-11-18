//! WebIDL dictionary: AuctionAd
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AuctionAd = struct {
    renderURL: runtime.DOMString,
    sizeGroup: ?runtime.DOMString = null,
    metadata: ?anyopaque = null,
    buyerReportingId: ?runtime.DOMString = null,
    buyerAndSellerReportingId: ?runtime.DOMString = null,
    selectableBuyerAndSellerReportingIds: ?anyopaque = null,
    allowedReportingOrigins: ?anyopaque = null,
    adRenderId: ?runtime.DOMString = null,
    creativeScanningMetadata: ?runtime.DOMString = null,
};
