//! WebIDL dictionary: RequestInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const AttributionReportingRequestOptions = @import("AttributionReportingRequestOptions.zig").AttributionReportingRequestOptions;
const PrivateToken = @import("PrivateToken.zig").PrivateToken;

pub const RequestInit = struct {
    method: ?runtime.ByteString = null,
    headers: ?typedefs.HeadersInit = null,
    body: ?typedefs.BodyInit = null,
    referrer: ?runtime.USVString = null,
    referrerPolicy: ?enums.ReferrerPolicy = null,
    mode: ?enums.RequestMode = null,
    credentials: ?enums.RequestCredentials = null,
    cache: ?enums.RequestCache = null,
    redirect: ?enums.RequestRedirect = null,
    integrity: ?runtime.DOMString = null,
    keepalive: ?bool = null,
    signal: ?*runtime.Instance = null,
    duplex: ?enums.RequestDuplex = null,
    priority: ?enums.RequestPriority = null,
    window: ?runtime.JSValue = null,
    attributionReporting: ?AttributionReportingRequestOptions = null,
    browsingTopics: ?bool = null,
    adAuctionHeaders: ?bool = null,
    targetAddressSpace: ?enums.IPAddressSpace = null,
    sharedStorageWritable: ?bool = null,
    privateToken: ?PrivateToken = null,
};
