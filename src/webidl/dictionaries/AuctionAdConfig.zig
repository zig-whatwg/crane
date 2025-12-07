//! WebIDL dictionary: AuctionAdConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const AuctionReportBuyersConfig = @import("AuctionReportBuyersConfig.zig").AuctionReportBuyersConfig;
const ProtectedAudiencePrivateAggregationConfig = @import("ProtectedAudiencePrivateAggregationConfig.zig").ProtectedAudiencePrivateAggregationConfig;
const AuctionRealTimeReportingConfig = @import("AuctionRealTimeReportingConfig.zig").AuctionRealTimeReportingConfig;
const AuctionReportBuyerDebugModeConfig = @import("AuctionReportBuyerDebugModeConfig.zig").AuctionReportBuyerDebugModeConfig;

pub const AuctionAdConfig = struct {
    seller: runtime.USVString,
    decisionLogicURL: runtime.USVString,
    trustedScoringSignalsURL: ?runtime.USVString = null,
    maxTrustedScoringSignalsURLLength: ?i32 = null,
    trustedScoringSignalsCoordinator: ?runtime.USVString = null,
    sendCreativeScanningMetadata: ?bool = null,
    interestGroupBuyers: ?[]const runtime.USVString = null,
    auctionSignals: ?*const anyopaque = null,
    sellerSignals: ?*const anyopaque = null,
    directFromSellerSignalsHeaderAdSlot: ?*const anyopaque = null,
    deprecatedRenderURLReplacements: ?*const anyopaque = null,
    sellerTimeout: ?u64 = null,
    sellerExperimentGroupId: ?u16 = null,
    perBuyerSignals: ?*const anyopaque = null,
    perBuyerTimeouts: ?*const anyopaque = null,
    perBuyerCumulativeTimeouts: ?*const anyopaque = null,
    reportingTimeout: ?u64 = null,
    sellerCurrency: ?runtime.USVString = null,
    perBuyerCurrencies: ?*const anyopaque = null,
    perBuyerMultiBidLimits: ?[]const struct { key: runtime.USVString, value: *const anyopaque } = null,
    perBuyerGroupLimits: ?[]const struct { key: runtime.USVString, value: *const anyopaque } = null,
    perBuyerExperimentGroupIds: ?[]const struct { key: runtime.USVString, value: *const anyopaque } = null,
    perBuyerPrioritySignals: ?[]const struct { key: runtime.USVString, value: []const struct { key: runtime.USVString, value: f64 } } = null,
    auctionReportBuyerKeys: ?[]const *const anyopaque = null,
    auctionReportBuyers: ?[]const struct { key: runtime.DOMString, value: AuctionReportBuyersConfig } = null,
    auctionReportBuyerDebugModeConfig: ?AuctionReportBuyerDebugModeConfig = null,
    requiredSellerCapabilities: ?[]const runtime.DOMString = null,
    privateAggregationConfig: ?ProtectedAudiencePrivateAggregationConfig = null,
    requestedSize: ?[]const struct { key: runtime.DOMString, value: runtime.DOMString } = null,
    allSlotsRequestedSizes: ?[]const []const struct { key: runtime.DOMString, value: runtime.DOMString } = null,
    additionalBids: ?*const anyopaque = null,
    auctionNonce: ?runtime.DOMString = null,
    sellerRealTimeReportingConfig: ?AuctionRealTimeReportingConfig = null,
    perBuyerRealTimeReportingConfig: ?[]const struct { key: runtime.USVString, value: AuctionRealTimeReportingConfig } = null,
    componentAuctions: ?[]const AuctionAdConfig = null,
    signal: ?*runtime.Instance = null,
    resolveToConfig: ?*const anyopaque = null,
    serverResponse: ?*const anyopaque = null,
    requestId: ?runtime.USVString = null,
};
