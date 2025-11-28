//! Fetch Internal Data Structures
//!
//! This module contains internal data structures used by the Fetch API
//! implementation that are not directly exposed to JavaScript.

pub const header_list = @import("header_list.zig");
pub const HeaderList = header_list.HeaderList;
pub const Header = header_list.Header;
pub const normalize = header_list.normalize;

pub const validation = @import("validation.zig");
pub const isValidHeaderName = validation.isValidHeaderName;
pub const isValidHeaderValue = validation.isValidHeaderValue;
pub const isCORSSafelistedRequestHeader = validation.isCORSSafelistedRequestHeader;
pub const containsCORSUnsafeBytes = validation.containsCORSUnsafeBytes;
pub const getCORSUnsafeRequestHeaderNames = validation.getCORSUnsafeRequestHeaderNames;
pub const isForbiddenRequestHeader = validation.isForbiddenRequestHeader;
pub const isForbiddenResponseHeaderName = validation.isForbiddenResponseHeaderName;
pub const isNoCORSSafelistedRequestHeader = validation.isNoCORSSafelistedRequestHeader;
pub const isCORSSafelistedResponseHeaderName = validation.isCORSSafelistedResponseHeaderName;
pub const isRequestBodyHeaderName = validation.isRequestBodyHeaderName;
pub const isCORSNonWildcardRequestHeaderName = validation.isCORSNonWildcardRequestHeaderName;
pub const isPrivilegedNoCORSRequestHeaderName = validation.isPrivilegedNoCORSRequestHeaderName;

pub const parsing = @import("parsing.zig");
pub const isHttpTabOrSpace = parsing.isHttpTabOrSpace;
pub const isHttpWhitespace = parsing.isHttpWhitespace;
pub const trimHttpTabOrSpace = parsing.trimHttpTabOrSpace;
pub const trimHttpWhitespace = parsing.trimHttpWhitespace;
pub const collectHttpQuotedString = parsing.collectHttpQuotedString;
pub const parseSingleRangeHeaderValue = parsing.parseSingleRangeHeaderValue;
pub const RangeValue = parsing.RangeValue;
pub const buildContentRange = parsing.buildContentRange;
pub const buildContentRangeUnsatisfiable = parsing.buildContentRangeUnsatisfiable;
pub const extractHeaderListValues = parsing.extractHeaderListValues;
pub const parseMimeType = parsing.parseMimeType;
pub const MimeType = parsing.MimeType;

pub const guards = @import("guards.zig");
pub const HeaderGuard = guards.HeaderGuard;
pub const canAppend = guards.canAppend;
pub const canSet = guards.canSet;
pub const canDelete = guards.canDelete;
pub const canGet = guards.canGet;

pub const body = @import("body.zig");
pub const Body = body.Body;
pub const BodySource = body.BodySource;
pub const BodyWithType = body.BodyWithType;
pub const nullBody = body.nullBody;
pub const isNullBody = body.isNullBody;

pub const fetch_timing = @import("fetch_timing.zig");
pub const FetchTimingInfo = fetch_timing.FetchTimingInfo;
pub const ConnectionTimingInfo = fetch_timing.ConnectionTimingInfo;
pub const ResponseBodyInfo = fetch_timing.ResponseBodyInfo;
pub const DOMHighResTimeStamp = fetch_timing.DOMHighResTimeStamp;
pub const createOpaqueTimingInfo = fetch_timing.createOpaqueTimingInfo;
pub const coarsenTime = fetch_timing.coarsenTime;
pub const clampAndCoarsenConnectionTimingInfo = fetch_timing.clampAndCoarsenConnectionTimingInfo;

pub const request = @import("request.zig");
pub const InternalRequest = request.InternalRequest;
pub const ServiceWorkersMode = request.ServiceWorkersMode;
pub const Initiator = request.Initiator;
pub const Destination = request.Destination;
pub const Priority = request.Priority;
pub const RequestMode = request.RequestMode;
pub const CredentialsMode = request.CredentialsMode;
pub const CacheMode = request.CacheMode;
pub const RedirectMode = request.RedirectMode;
pub const ResponseTainting = request.ResponseTainting;
pub const ParserMetadata = request.ParserMetadata;
pub const InitiatorType = request.InitiatorType;
pub const ReferrerPolicy = request.ReferrerPolicy;

pub const response = @import("response.zig");
pub const InternalResponse = response.InternalResponse;
pub const ResponseType = response.ResponseType;
pub const CacheState = response.CacheState;
pub const FilteredResponse = response.FilteredResponse;
pub const FilterType = response.FilterType;
pub const networkError = response.networkError;
pub const abortedNetworkError = response.abortedNetworkError;
pub const isNullBodyStatus = response.isNullBodyStatus;
pub const isOkStatus = response.isOkStatus;
pub const isRedirectStatus = response.isRedirectStatus;
pub const createBasicFilteredResponse = response.createBasicFilteredResponse;
pub const createCORSFilteredResponse = response.createCORSFilteredResponse;
pub const createOpaqueFilteredResponse = response.createOpaqueFilteredResponse;
pub const createOpaqueRedirectFilteredResponse = response.createOpaqueRedirectFilteredResponse;

test {
    _ = header_list;
    _ = validation;
    _ = parsing;
    _ = guards;
    _ = body;
    _ = fetch_timing;
    _ = request;
    _ = response;
}
