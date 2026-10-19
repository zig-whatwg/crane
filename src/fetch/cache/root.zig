//! The HTTP cache (RFC 9111) and Fetch's use of it (HTTP-network-or-cache
//! fetch, Fetch 4.6).
//!
//! - `http_cache.zig` - the Browser's store: one stored response per
//!   (network partition key, URL), LRU within caps, shared by its threads
//! - `stored_response.zig` - a stored response: immutable, counted, its Vary
//!   data and freshness inputs
//! - `cache_control.zig` - Cache-Control directives (RFC 9111 5.2)
//! - `freshness.zig` - freshness lifetime and age (4.2), and the HTTP-date
//!   parser (RFC 9110 5.6.7) document.lastModified shares
//! - `header_view.zig` - a request's header list as the cache reads it
//!
//! Spec: https://fetch.spec.whatwg.org/#http-network-or-cache-fetch
//!       https://www.rfc-editor.org/rfc/rfc9111 (obsoletes RFC 7234)

const std = @import("std");

pub const cache_control = @import("cache_control.zig");
pub const freshness_mod = @import("freshness.zig");
pub const header_view = @import("header_view.zig");
pub const stored_response = @import("stored_response.zig");
pub const http_cache = @import("http_cache.zig");

pub const Directives = cache_control.Directives;
pub const HeaderView = header_view.HeaderView;
pub const StoredResponse = stored_response.StoredResponse;
pub const HttpCache = http_cache.HttpCache;
pub const Config = http_cache.Config;
pub const keyUrl = http_cache.keyUrl;

pub const parseHttpDate = freshness_mod.parseHttpDate;

test {
    std.testing.refAllDecls(@This());
}
