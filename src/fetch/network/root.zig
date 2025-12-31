//! Network Module - WHATWG Fetch Implementation
//!
//! This module provides the network abstraction layer for Fetch.
//!
//! ## Components
//!
//! - `backend.zig` - NetworkBackend trait and MockBackend for testing
//! - `curl_ffi.zig` - FFI bindings for libcurl C API
//!
//! ## Usage
//!
//! ```zig
//! const network = @import("fetch").network;
//!
//! // Create a mock backend for testing
//! const mock = network.MockBackend.init(allocator);
//! defer mock.deinit();
//!
//! // Add canned responses
//! try mock.addResponse("https://api.example.com/data", .{
//!     .status = 200,
//!     .headers = &.{.{ .name = "Content-Type", .value = "application/json" }},
//!     .body = "{\"result\": \"success\"}",
//! });
//!
//! // Use as NetworkBackend interface
//! const backend = mock.backend();
//!
//! // Make request
//! const request = network.NetworkRequest{
//!     .url = "https://api.example.com/data",
//!     .method = "GET",
//!     .headers = &.{},
//!     .body = null,
//! };
//!
//! var response = try backend.send(allocator, &request);
//! defer response.deinit();
//! ```

const std = @import("std");

pub const backend = @import("backend.zig");
pub const curl_ffi = @import("curl_ffi.zig");
pub const curl_error = @import("curl_error.zig");
pub const curl_backend = @import("curl_backend.zig");
pub const curl_cookies = @import("curl_cookies.zig");
pub const cookie_store = @import("cookie_store.zig");
pub const connection_pool = @import("connection_pool.zig");
pub const streaming_source = @import("streaming_source.zig");
pub const async_curl_manager = @import("async_curl_manager.zig");
pub const certificate_trust = @import("certificate_trust.zig");

// Re-export main types
pub const NetworkBackend = backend.NetworkBackend;
pub const NetworkRequest = backend.NetworkRequest;
pub const NetworkResponse = backend.NetworkResponse;
pub const NetworkError = backend.NetworkError;
pub const MockBackend = backend.MockBackend;
pub const HttpVersion = backend.HttpVersion;
pub const TlsVersion = backend.TlsVersion;
pub const ProxyConfig = backend.ProxyConfig;
pub const CertVerifyOptions = backend.CertVerifyOptions;
pub const ConnectionTimingInfo = backend.ConnectionTimingInfo;

// Re-export libcurl backend
pub const LibcurlBackend = curl_backend.LibcurlBackend;
pub const globalInit = curl_backend.globalInit;
pub const globalCleanup = curl_backend.globalCleanup;

// Re-export connection pool
pub const ConnectionPool = connection_pool.ConnectionPool;
pub const getGlobalPool = connection_pool.getGlobalPool;
pub const cleanupGlobalPool = connection_pool.cleanupGlobalPool;

// Re-export streaming types
pub const StreamingSource = streaming_source.StreamingSource;
pub const StreamingState = streaming_source.StreamingState;
pub const ChunkIterator = streaming_source.ChunkIterator;
pub const DEFAULT_CHUNK_SIZE = streaming_source.DEFAULT_CHUNK_SIZE;

// Re-export cookie manager
pub const CurlCookieManager = curl_cookies.CurlCookieManager;
pub const Cookie = curl_cookies.Cookie;
pub const CookieError = curl_cookies.CookieError;

// Re-export async HTTP manager
pub const AsyncCurlManager = async_curl_manager.AsyncCurlManager;
pub const AsyncResult = async_curl_manager.AsyncResult;

// Re-export certificate trust store
pub const CertificateTrustStore = certificate_trust.CertificateTrustStore;
pub const TrustedCertificate = certificate_trust.TrustedCertificate;
pub const TrustedCertificateOptions = certificate_trust.TrustedCertificateOptions;

// Re-export CookieStore API
pub const CookieStore = cookie_store.CookieStore;
pub const CookieListItem = cookie_store.CookieListItem;
pub const CookieSameSite = cookie_store.CookieSameSite;
pub const CookieStoreGetOptions = cookie_store.CookieStoreGetOptions;
pub const CookieInit = cookie_store.CookieInit;
pub const CookieStoreDeleteOptions = cookie_store.CookieStoreDeleteOptions;
pub const getGlobalCookieStore = cookie_store.getGlobalCookieStore;
pub const cleanupGlobalCookieStore = cookie_store.cleanupGlobalCookieStore;

test {
    std.testing.refAllDecls(@This());
}
