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

pub const fetch_controller = @import("fetch_controller.zig");
pub const FetchController = fetch_controller.FetchController;
pub const deserializeAbortReason = fetch_controller.deserializeAbortReason;

pub const fetch_params = @import("fetch_params.zig");
pub const FetchParams = fetch_params.FetchParams;
pub const TaskDestination = fetch_params.TaskDestination;
pub const ParallelQueue = fetch_params.ParallelQueue;
pub const queueFetchTask = fetch_params.queueFetchTask;
pub const createAppropriateNetworkError = fetch_params.createAppropriateNetworkError;

pub const body_extraction = @import("body_extraction.zig");
pub const BodyInit = body_extraction.BodyInit;
pub const BufferSource = body_extraction.BufferSource;
pub const extract = body_extraction.extract;
pub const safelyExtract = body_extraction.safelyExtract;
pub const CONTENT_TYPE_TEXT_PLAIN = body_extraction.CONTENT_TYPE_TEXT_PLAIN;
pub const CONTENT_TYPE_FORM_URLENCODED = body_extraction.CONTENT_TYPE_FORM_URLENCODED;
pub const CONTENT_TYPE_MULTIPART_PREFIX = body_extraction.CONTENT_TYPE_MULTIPART_PREFIX;

pub const body_cloning = @import("body_cloning.zig");
pub const BodyCloneError = body_cloning.BodyCloneError;
pub const isBodyUsed = body_cloning.isBodyUsed;
pub const canClone = body_cloning.canClone;
pub const cloneBody = body_cloning.cloneBody;
pub const cloneBodyOrThrow = body_cloning.cloneBodyOrThrow;
pub const cloneRequestBody = body_cloning.cloneRequestBody;
pub const cloneRequestBodyOrThrow = body_cloning.cloneRequestBodyOrThrow;
pub const cloneResponseBody = body_cloning.cloneResponseBody;
pub const cloneResponseBodyOrThrow = body_cloning.cloneResponseBodyOrThrow;

test {
    _ = header_list;
    _ = validation;
    _ = parsing;
    _ = guards;
    _ = body;
    _ = fetch_timing;
    _ = request;
    _ = response;
    _ = fetch_controller;
    _ = fetch_params;
    _ = body_extraction;
    _ = body_cloning;
}
