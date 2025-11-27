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

test {
    _ = header_list;
    _ = validation;
    _ = parsing;
    _ = guards;
}
