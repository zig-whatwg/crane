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
    auctionSignals: ?runtime.JSValue = null,
    sellerSignals: ?runtime.JSValue = null,
    directFromSellerSignalsHeaderAdSlot: ?runtime.JSValue = null,
    deprecatedRenderURLReplacements: ?runtime.JSValue = null,
    sellerTimeout: ?u64 = null,
    sellerExperimentGroupId: ?u16 = null,
    perBuyerSignals: ?runtime.JSValue = null,
    perBuyerTimeouts: ?runtime.JSValue = null,
    perBuyerCumulativeTimeouts: ?runtime.JSValue = null,
    reportingTimeout: ?u64 = null,
    sellerCurrency: ?runtime.USVString = null,
    perBuyerCurrencies: ?runtime.JSValue = null,
    perBuyerMultiBidLimits: ?[]const struct { key: runtime.USVString, value: runtime.JSValue } = null,
    perBuyerGroupLimits: ?[]const struct { key: runtime.USVString, value: runtime.JSValue } = null,
    perBuyerExperimentGroupIds: ?[]const struct { key: runtime.USVString, value: runtime.JSValue } = null,
    perBuyerPrioritySignals: ?[]const struct { key: runtime.USVString, value: []const struct { key: runtime.USVString, value: f64 } } = null,
    auctionReportBuyerKeys: ?[]const runtime.JSValue = null,
    auctionReportBuyers: ?[]const struct { key: runtime.DOMString, value: AuctionReportBuyersConfig } = null,
    auctionReportBuyerDebugModeConfig: ?AuctionReportBuyerDebugModeConfig = null,
    requiredSellerCapabilities: ?[]const runtime.DOMString = null,
    privateAggregationConfig: ?ProtectedAudiencePrivateAggregationConfig = null,
    requestedSize: ?[]const struct { key: runtime.DOMString, value: runtime.DOMString } = null,
    allSlotsRequestedSizes: ?[]const []const struct { key: runtime.DOMString, value: runtime.DOMString } = null,
    additionalBids: ?runtime.JSValue = null,
    auctionNonce: ?runtime.DOMString = null,
    sellerRealTimeReportingConfig: ?AuctionRealTimeReportingConfig = null,
    perBuyerRealTimeReportingConfig: ?[]const struct { key: runtime.USVString, value: AuctionRealTimeReportingConfig } = null,
    componentAuctions: ?[]const AuctionAdConfig = null,
    signal: ?*runtime.Instance = null,
    resolveToConfig: ?runtime.JSValue = null,
    serverResponse: ?runtime.JSValue = null,
    requestId: ?runtime.USVString = null,
};
