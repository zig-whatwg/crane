//! RFC 6265bis Cookie Module
//!
//! Spec: https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
//!
//! This module provides cookie handling for the Fetch specification:
//! - Cookie struct with all RFC 6265bis attributes
//! - CookieStore for storing and retrieving cookies
//! - Set-Cookie header parsing
//! - Cookie header building
//! - Domain and path matching
//! - SameSite determination
//!
//! ## Usage
//!
//! ```zig
//! const cookies = @import("fetch").cookies;
//!
//! // Create a cookie store
//! var store = cookies.CookieStore.init(allocator);
//! defer store.deinit();
//!
//! // Store a cookie from Set-Cookie header
//! try store.setCookie("session=abc123; Path=/; Secure", "example.com", "/", true);
//!
//! // Get cookies for a request
//! const matching = try store.getCookiesForRequest(
//!     "example.com",
//!     "/api",
//!     true,
//!     .same_site,
//!     .subresource,
//! );
//! defer allocator.free(matching);
//!
//! // Build Cookie header
//! const header = try cookies.buildCookieHeader(allocator, matching);
//! defer allocator.free(header);
//! ```
//!
//! TODO(cookie-store-api): This internal cookie store provides the storage
//! backend for Fetch's credentials handling. When the Cookie Store API
//! (https://wicg.github.io/cookie-store/) is implemented, this should:
//! 1. Be the backing store for CookieStore interface
//! 2. Fire change events when cookies are modified
//! 3. Support subscriptions for Service Workers

const std = @import("std");

pub const cookie = @import("cookie.zig");
pub const matching = @import("matching.zig");
pub const parsing = @import("parsing.zig");
pub const same_site = @import("same_site.zig");
pub const store = @import("store.zig");

// Re-export main types
pub const Cookie = cookie.Cookie;
pub const SameSite = cookie.SameSite;
pub const CookieStore = store.CookieStore;
pub const SameSiteStatus = same_site.SameSiteStatus;
pub const RequestType = same_site.RequestType;

// Re-export functions
pub const parseSetCookie = parsing.parseSetCookie;
pub const buildCookieHeader = parsing.buildCookieHeader;
pub const domainMatches = matching.domainMatches;
pub const domainMatch = matching.domainMatch;
pub const pathMatches = matching.pathMatches;
pub const defaultPath = matching.defaultPath;
pub const determineSameSiteStatus = same_site.determineSameSiteStatus;
pub const shouldIncludeCookie = same_site.shouldIncludeCookie;
pub const getRegistrableDomain = same_site.getRegistrableDomain;

test {
    std.testing.refAllDecls(@This());
}
