//! Cookie Store API Implementation
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//! RFC 6265bis: https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
//!
//! This module provides a native Zig implementation of the WHATWG CookieStore API,
//! which provides an asynchronous interface for reading and writing cookies.
//!
//! ## Architecture
//!
//! ```
//! CookieStore (WebIDL interface)
//!     └── CookieJar (collection management)
//!         └── Cookie (individual cookie data)
//!             └── Validation (RFC 6265bis rules)
//!                 └── Domain/Path Matching (PSL integration)
//! ```
//!
//! ## Features
//!
//! - Async get/getAll/set/delete operations
//! - CookieChangeEvent for observing cookie changes
//! - Service Worker integration with CookieStoreManager
//! - CHIPS (Cookies Having Independent Partitioned State) support
//! - Comprehensive RFC 6265bis validation
//!
//! ## Security
//!
//! - SecureContext enforcement
//! - Opaque origin rejection
//! - HttpOnly cookies never exposed to JavaScript
//! - SameSite enforcement
//! - Public suffix validation via PSL
//! - Cookie prefix validation (__Host-, __Secure-)
//!
//! ## Usage
//!
//! ```zig
//! const cookiestore = @import("cookiestore");
//!
//! // Create a cookie
//! var cookie = try cookiestore.Cookie.init(allocator, "session_id", "abc123");
//! defer cookie.deinit();
//!
//! // Set attributes
//! cookie.secure = true;
//! cookie.same_site = .strict;
//! try cookie.setDomain("example.com");
//! ```

const std = @import("std");

// Core types
pub const cookie = @import("cookie.zig");
pub const Cookie = cookie.Cookie;
pub const SameSite = cookie.SameSite;
pub const PartitionKey = cookie.PartitionKey;
pub const CookieListItem = cookie.CookieListItem;

// Validation
pub const validation = @import("validation.zig");
pub const ValidationError = validation.ValidationError;
pub const validateName = validation.validateName;
pub const validateValue = validation.validateValue;
pub const validateNameValue = validation.validateNameValue;
pub const validatePrefixes = validation.validatePrefixes;
pub const validateDomain = validation.validateDomain;
pub const validatePath = validation.validatePath;
pub const hasHostPrefix = validation.hasHostPrefix;
pub const hasSecurePrefix = validation.hasSecurePrefix;
pub const MAX_NAME_VALUE_SIZE = validation.MAX_NAME_VALUE_SIZE;
pub const MAX_ATTRIBUTE_VALUE_SIZE = validation.MAX_ATTRIBUTE_VALUE_SIZE;

// Domain and path matching
pub const domain_matching = @import("domain_matching.zig");
pub const domainMatches = domain_matching.domainMatches;
pub const pathMatches = domain_matching.pathMatches;
pub const getDefaultPath = domain_matching.getDefaultPath;
pub const isPublicSuffix = domain_matching.isPublicSuffix;
pub const isRegistrableDomainSuffixOrEqual = domain_matching.isRegistrableDomainSuffixOrEqual;
pub const normalizeDomain = domain_matching.normalizeDomain;

test {
    _ = cookie;
    _ = validation;
    _ = domain_matching;
}
