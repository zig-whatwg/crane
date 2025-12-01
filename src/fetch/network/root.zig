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

test {
    std.testing.refAllDecls(@This());
}
