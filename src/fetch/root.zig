//! WHATWG Fetch Standard Implementation
//!
//! This module implements the WHATWG Fetch Standard in Zig.
//! Spec: https://fetch.spec.whatwg.org/
//!
//! ## Modules
//!
//! - `internal`: Internal data structures (header list, request/response internals)
//! - `referrer_policy`: W3C Referrer Policy implementation
//! - `cookies`: RFC 6265bis cookie handling
//! - `cors`: CORS check and validation algorithms
//!
//! ## Usage
//!
//! ```zig
//! const fetch = @import("fetch");
//!
//! // Create a header list
//! var headers = fetch.internal.HeaderList.init(allocator);
//! defer headers.deinit();
//!
//! try headers.append("Content-Type", "application/json");
//! try headers.append("Accept", "application/json");
//!
//! // Use referrer policy
//! const policy = fetch.referrer_policy.ReferrerPolicy.parse("strict-origin");
//!
//! // Use cookie store
//! var store = fetch.cookies.CookieStore.init(allocator);
//! defer store.deinit();
//!
//! // Use CORS check
//! const result = fetch.cors.corsCheck("https://example.com", .omit, response_headers);
//! ```

pub const internal = @import("internal/root.zig");
pub const referrer_policy = @import("referrer_policy");
pub const cors = @import("cors/root.zig");
pub const network = @import("network/root.zig");
pub const cache = @import("cache/root.zig");
pub const algorithms = @import("algorithms/root.zig");
pub const webidl = @import("webidl/root.zig");
pub const interception = @import("interception/root.zig");

// Re-export commonly used types
pub const HeaderList = internal.HeaderList;
pub const Header = internal.Header;

// Re-export referrer policy types
pub const ReferrerPolicy = referrer_policy.ReferrerPolicy;

// Re-export cookie types (from unified curl-based implementation)
pub const CurlCookieManager = network.curl_cookies.CurlCookieManager;
pub const Cookie = network.curl_cookies.Cookie;
pub const CookieStore = network.cookie_store.CookieStore;

// Re-export CORS types
pub const CredentialsMode = cors.CredentialsMode;
pub const corsCheck = cors.corsCheck;

// Re-export network types
pub const NetworkBackend = network.NetworkBackend;
pub const NetworkRequest = network.NetworkRequest;
pub const NetworkResponse = network.NetworkResponse;
pub const NetworkError = network.NetworkError;
pub const MockBackend = network.MockBackend;

// Re-export cache types
pub const CacheBackend = cache.CacheBackend;
pub const CacheKey = cache.CacheKey;
pub const CacheEntry = cache.CacheEntry;
pub const CacheControl = cache.CacheControl;
pub const MemoryCacheBackend = cache.MemoryCacheBackend;

// Re-export algorithm types and functions
pub const processDataUrl = algorithms.processDataUrl;
pub const DataUrlResult = algorithms.DataUrlResult;
pub const schemeFetch = algorithms.schemeFetch;
pub const SchemeFetchResult = algorithms.SchemeFetchResult;
pub const fetch = algorithms.fetch;
pub const fetchSimple = algorithms.fetchSimple;
pub const FetchResult = algorithms.FetchResult;
pub const FetchError = algorithms.FetchError;

// Re-export WebIDL types
pub const Headers = webidl.Headers;
pub const Request = webidl.Request;
pub const Response = webidl.Response;

test {
    _ = internal;
    _ = referrer_policy;
    _ = cors;
    _ = network;
    _ = cache;
    _ = algorithms;
    _ = webidl;
}
