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

test {
    _ = cookie;
}
