//! Network Backend Trait - WHATWG Fetch Implementation
//!
//! This module defines the NetworkBackend interface that abstracts network
//! operations for the Fetch specification. Implementations can use libcurl,
//! native system APIs, or mock backends for testing.
//!
//! Spec: https://fetch.spec.whatwg.org/#http-network-fetch
//!
//! The backend handles:
//! - HTTP/1.1 and HTTP/2 connections
//! - TLS/SSL certificate validation
//! - Connection pooling and keep-alive
//! - Request/response streaming
//! - Proxy support
//! - Cookie handling (delegated to cookie store)

const std = @import("std");
const Allocator = std.mem.Allocator;

// =============================================================================
// Network Request/Response Types
// =============================================================================

/// HTTP version to use for requests.
pub const HttpVersion = enum {
    http_1_0,
    http_1_1,
    http_2,
    http_3,

    /// Return string representation for debugging.
    pub fn toString(self: HttpVersion) []const u8 {
        return switch (self) {
            .http_1_0 => "HTTP/1.0",
            .http_1_1 => "HTTP/1.1",
            .http_2 => "HTTP/2",
            .http_3 => "HTTP/3",
        };
    }
};

/// TLS version constraints.
pub const TlsVersion = enum {
    tls_1_0,
    tls_1_1,
    tls_1_2,
    tls_1_3,
};

/// Proxy configuration.
pub const ProxyConfig = struct {
    /// Proxy URL (e.g., "http://proxy.example.com:8080")
    url: []const u8,
    /// Username for proxy authentication (optional)
    username: ?[]const u8 = null,
    /// Password for proxy authentication (optional)
    password: ?[]const u8 = null,
    /// Bypass proxy for these hosts (comma-separated)
    no_proxy: ?[]const u8 = null,
};

/// Certificate verification options.
pub const CertVerifyOptions = struct {
    /// Verify the server's certificate chain
    verify_peer: bool = true,
    /// Verify the server's hostname matches certificate
    verify_host: bool = true,
    /// Path to CA certificate bundle (null = system default)
    ca_bundle_path: ?[]const u8 = null,
    /// Path to client certificate (for mutual TLS)
    client_cert_path: ?[]const u8 = null,
    /// Path to client private key (for mutual TLS)
    client_key_path: ?[]const u8 = null,
};

/// Network request configuration.
pub const NetworkRequest = struct {
    /// Request URL
    url: []const u8,
    /// HTTP method
    method: []const u8,
    /// Request headers as name-value pairs
    headers: []const Header,
    /// Request body (null for no body)
    body: ?[]const u8,
    /// HTTP version preference
    http_version: HttpVersion = .http_1_1,
    /// Connection timeout in milliseconds
    connect_timeout_ms: u32 = 30_000,
    /// Total request timeout in milliseconds (0 = no timeout)
    timeout_ms: u32 = 0,
    /// Follow redirects (for backends that support it)
    follow_redirects: bool = false,
    /// Maximum number of redirects to follow
    max_redirects: u32 = 20,
    /// Proxy configuration (null = no proxy)
    proxy: ?ProxyConfig = null,
    /// Certificate verification options
    cert_options: CertVerifyOptions = .{},
    /// Enable verbose logging (for debugging)
    verbose: bool = false,

    pub const Header = struct {
        name: []const u8,
        value: []const u8,
    };
};

/// Network response from backend.
pub const NetworkResponse = struct {
    allocator: Allocator,

    /// HTTP status code
    status: u16,
    /// HTTP version used
    http_version: HttpVersion,
    /// Response headers
    headers: []Header,
    /// Response body (may be null for HEAD requests or errors)
    body: ?[]const u8,
    /// Final URL after redirects (if different from request URL)
    final_url: ?[]const u8,
    /// Total time in milliseconds
    total_time_ms: u64,
    /// Time to first byte in milliseconds
    time_to_first_byte_ms: u64,
    /// Number of redirects followed
    redirect_count: u32,
    /// Remote IP address
    remote_ip: ?[]const u8,
    /// Remote port
    remote_port: ?u16,

    // === Resource Timing API fields ===
    // All times are in milliseconds from request start

    /// Time when DNS lookup completed
    dns_lookup_time_ms: u64 = 0,
    /// Time when TCP connection completed
    connect_time_ms: u64 = 0,
    /// Time when TLS handshake completed (0 for non-HTTPS)
    app_connect_time_ms: u64 = 0,
    /// Time when request was ready to transfer
    pretransfer_time_ms: u64 = 0,
    /// Time spent in redirects (when following redirects)
    redirect_time_ms: u64 = 0,
    /// Whether connection was reused from pool
    connection_reused: bool = false,

    pub const Header = struct {
        name: []const u8,
        value: []const u8,
    };

    /// Free all allocated memory.
    pub fn deinit(self: *NetworkResponse) void {
        // Free headers
        for (self.headers) |header| {
            self.allocator.free(header.name);
            self.allocator.free(header.value);
        }
        self.allocator.free(self.headers);

        // Free body
        if (self.body) |body| {
            self.allocator.free(body);
        }

        // Free final URL
        if (self.final_url) |url| {
            self.allocator.free(url);
        }

        // Free remote IP
        if (self.remote_ip) |ip| {
            self.allocator.free(ip);
        }
    }
};

/// Network error types.
pub const NetworkError = error{
    /// Failed to resolve hostname
    DnsResolutionFailed,
    /// Connection refused by server
    ConnectionRefused,
    /// Connection timed out
    ConnectionTimeout,
    /// Request timed out
    RequestTimeout,
    /// SSL/TLS handshake failed
    SslHandshakeFailed,
    /// SSL/TLS certificate verification failed
    SslCertificateError,
    /// Too many redirects
    TooManyRedirects,
    /// Invalid URL
    InvalidUrl,
    /// Request was aborted
    Aborted,
    /// Network is unreachable
    NetworkUnreachable,
    /// Host is unreachable
    HostUnreachable,
    /// Connection reset by peer
    ConnectionReset,
    /// Protocol error
    ProtocolError,
    /// Out of memory
    OutOfMemory,
    /// Unknown/unspecified error
    Unknown,
};

// =============================================================================
// Network Backend Interface
// =============================================================================

/// NetworkBackend is a vtable-based interface for network operations.
///
/// Implementations:
/// - MockBackend: For testing fetch algorithms without network
/// - LibcurlBackend: Production backend using libcurl (planned)
///
/// ## VTable Pattern and Type Erasure
///
/// This struct uses `*anyopaque` for the `ptr` field intentionally. This is the
/// idiomatic Zig pattern for type-erased interfaces (like vtables). The pattern:
///
/// 1. Store type-erased pointer (`*anyopaque`) alongside vtable
/// 2. VTable functions receive the erased pointer and cast it back
/// 3. This enables runtime polymorphism without generics
///
/// This is NOT a code smell - it's the correct approach for interfaces that:
/// - Need runtime dispatch (different backends selected at runtime)
/// - Don't benefit from comptime generics
/// - Follow the standard Zig pattern (see std.mem.Allocator)
///
/// Usage:
/// ```zig
/// const backend = MockBackend.init(allocator);
/// defer backend.deinit();
///
/// const response = try backend.send(&request);
/// defer response.deinit();
/// ```
pub const NetworkBackend = struct {
    /// Opaque pointer to backend implementation.
    ///
    /// This uses `*anyopaque` intentionally for type erasure - this is the
    /// idiomatic Zig pattern for vtable-based polymorphism. The VTable
    /// functions cast this back to the concrete type.
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Send a network request and return the response.
        send: *const fn (ptr: *anyopaque, allocator: Allocator, request: *const NetworkRequest) NetworkError!NetworkResponse,

        /// Abort an in-flight request (if supported).
        abort: *const fn (ptr: *anyopaque) void,

        /// Check if the backend supports streaming responses.
        supportsStreaming: *const fn (ptr: *anyopaque) bool,

        /// Get backend name for debugging.
        getName: *const fn (ptr: *anyopaque) []const u8,

        /// Clean up backend resources.
        deinit: *const fn (ptr: *anyopaque) void,
    };

    /// Send a network request.
    pub fn send(self: NetworkBackend, allocator: Allocator, request: *const NetworkRequest) NetworkError!NetworkResponse {
        return self.vtable.send(self.ptr, allocator, request);
    }

    /// Abort an in-flight request.
    pub fn abort(self: NetworkBackend) void {
        self.vtable.abort(self.ptr);
    }

    /// Check if backend supports streaming.
    pub fn supportsStreaming(self: NetworkBackend) bool {
        return self.vtable.supportsStreaming(self.ptr);
    }

    /// Get backend name.
    pub fn getName(self: NetworkBackend) []const u8 {
        return self.vtable.getName(self.ptr);
    }

    /// Clean up backend.
    pub fn deinit(self: NetworkBackend) void {
        self.vtable.deinit(self.ptr);
    }
};

// =============================================================================
// Mock Backend (for testing)
// =============================================================================

/// MockBackend provides a configurable mock for testing fetch algorithms
/// without making actual network requests.
pub const MockBackend = struct {
    allocator: Allocator,
    /// Canned responses keyed by URL
    responses: std.StringHashMapUnmanaged(MockResponse),
    /// Default response for unmatched URLs
    default_response: ?MockResponse,
    /// Record of requests made
    request_history: std.ArrayListUnmanaged(RecordedRequest),
    /// Whether to simulate network delay
    simulate_delay: bool,
    /// Simulated delay in milliseconds
    delay_ms: u32,
    /// Force all requests to fail with this error
    force_error: ?NetworkError,
    /// Aborted flag
    aborted: bool,

    pub const MockResponse = struct {
        status: u16 = 200,
        headers: []const NetworkResponse.Header = &.{},
        body: ?[]const u8 = null,
        error_to_return: ?NetworkError = null,
    };

    pub const RecordedRequest = struct {
        url: []const u8,
        method: []const u8,
        headers: []const NetworkRequest.Header,
        body: ?[]const u8,
    };

    const Self = @This();

    /// Initialize a new mock backend.
    pub fn init(allocator: Allocator) *Self {
        const self = allocator.create(Self) catch @panic("OOM");
        self.* = .{
            .allocator = allocator,
            .responses = .{},
            .default_response = null,
            .request_history = .{},
            .simulate_delay = false,
            .delay_ms = 0,
            .force_error = null,
            .aborted = false,
        };
        return self;
    }

    /// Clean up mock backend.
    pub fn deinit(self: *Self) void {
        // Free response keys
        var it = self.responses.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.responses.deinit(self.allocator);

        // Free request history
        for (self.request_history.items) |req| {
            self.allocator.free(req.url);
            self.allocator.free(req.method);
            for (req.headers) |h| {
                self.allocator.free(h.name);
                self.allocator.free(h.value);
            }
            self.allocator.free(req.headers);
            if (req.body) |b| self.allocator.free(b);
        }
        self.request_history.deinit(self.allocator);

        self.allocator.destroy(self);
    }

    /// Add a canned response for a URL.
    pub fn addResponse(self: *Self, url: []const u8, response: MockResponse) !void {
        const owned_url = try self.allocator.dupe(u8, url);
        try self.responses.put(self.allocator, owned_url, response);
    }

    /// Set the default response for unmatched URLs.
    pub fn setDefaultResponse(self: *Self, response: MockResponse) void {
        self.default_response = response;
    }

    /// Enable network delay simulation.
    pub fn setDelay(self: *Self, delay_ms: u32) void {
        self.simulate_delay = true;
        self.delay_ms = delay_ms;
    }

    /// Force all requests to fail with an error.
    pub fn setForceError(self: *Self, err: NetworkError) void {
        self.force_error = err;
    }

    /// Clear force error.
    pub fn clearForceError(self: *Self) void {
        self.force_error = null;
    }

    /// Get the request history.
    pub fn getRequestHistory(self: *const Self) []const RecordedRequest {
        return self.request_history.items;
    }

    /// Clear request history.
    pub fn clearHistory(self: *Self) void {
        for (self.request_history.items) |req| {
            self.allocator.free(req.url);
            self.allocator.free(req.method);
            for (req.headers) |h| {
                self.allocator.free(h.name);
                self.allocator.free(h.value);
            }
            self.allocator.free(req.headers);
            if (req.body) |b| self.allocator.free(b);
        }
        self.request_history.clearRetainingCapacity();
    }

    /// Get as NetworkBackend interface.
    pub fn backend(self: *Self) NetworkBackend {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    // VTable implementation
    const vtable = NetworkBackend.VTable{
        .send = sendImpl,
        .abort = abortImpl,
        .supportsStreaming = supportsStreamingImpl,
        .getName = getNameImpl,
        .deinit = deinitImpl,
    };

    fn sendImpl(ptr: *anyopaque, allocator: Allocator, request: *const NetworkRequest) NetworkError!NetworkResponse {
        const self: *Self = @ptrCast(@alignCast(ptr));

        // Check if aborted
        if (self.aborted) {
            return NetworkError.Aborted;
        }

        // Check for forced error
        if (self.force_error) |err| {
            return err;
        }

        // Record the request
        const recorded = RecordedRequest{
            .url = self.allocator.dupe(u8, request.url) catch return NetworkError.OutOfMemory,
            .method = self.allocator.dupe(u8, request.method) catch return NetworkError.OutOfMemory,
            .headers = blk: {
                const hdrs = self.allocator.alloc(NetworkRequest.Header, request.headers.len) catch return NetworkError.OutOfMemory;
                for (request.headers, 0..) |h, i| {
                    hdrs[i] = .{
                        .name = self.allocator.dupe(u8, h.name) catch return NetworkError.OutOfMemory,
                        .value = self.allocator.dupe(u8, h.value) catch return NetworkError.OutOfMemory,
                    };
                }
                break :blk hdrs;
            },
            .body = if (request.body) |b| self.allocator.dupe(u8, b) catch return NetworkError.OutOfMemory else null,
        };
        self.request_history.append(self.allocator, recorded) catch return NetworkError.OutOfMemory;

        // Simulate delay (note: in tests, delay simulation is typically disabled
        // or we just record the intended delay rather than actually sleeping)
        _ = self.simulate_delay;
        _ = self.delay_ms;

        // Look up response
        const mock_response: MockResponse = self.responses.get(request.url) orelse self.default_response orelse MockResponse{
            .status = 404,
            .body = "Not Found",
        };

        // Check for error response
        if (mock_response.error_to_return) |err| {
            return err;
        }

        // Build response
        const headers = allocator.alloc(NetworkResponse.Header, mock_response.headers.len) catch return NetworkError.OutOfMemory;
        for (mock_response.headers, 0..) |h, i| {
            headers[i] = .{
                .name = allocator.dupe(u8, h.name) catch return NetworkError.OutOfMemory,
                .value = allocator.dupe(u8, h.value) catch return NetworkError.OutOfMemory,
            };
        }

        return NetworkResponse{
            .allocator = allocator,
            .status = mock_response.status,
            .http_version = .http_1_1,
            .headers = headers,
            .body = if (mock_response.body) |b| allocator.dupe(u8, b) catch return NetworkError.OutOfMemory else null,
            .final_url = null,
            .total_time_ms = if (self.simulate_delay) self.delay_ms else 0,
            .time_to_first_byte_ms = 0,
            .redirect_count = 0,
            .remote_ip = null,
            .remote_port = null,
        };
    }

    fn abortImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.aborted = true;
    }

    fn supportsStreamingImpl(_: *anyopaque) bool {
        return false;
    }

    fn getNameImpl(_: *anyopaque) []const u8 {
        return "MockBackend";
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

// =============================================================================
// Connection Timing Info
// =============================================================================

/// Connection timing information for Resource Timing API.
/// Spec: https://w3c.github.io/resource-timing/#dom-performanceresourcetiming-secureconnectionstart
pub const ConnectionTimingInfo = struct {
    /// Time when DNS lookup started (relative to fetch start)
    dns_start_ms: u64 = 0,
    /// Time when DNS lookup ended
    dns_end_ms: u64 = 0,
    /// Time when connection started
    connect_start_ms: u64 = 0,
    /// Time when connection ended (TCP handshake complete)
    connect_end_ms: u64 = 0,
    /// Time when TLS handshake started (0 if not TLS)
    secure_connection_start_ms: u64 = 0,
    /// Whether this connection was reused from pool
    connection_reused: bool = false,
    /// ALPN protocol negotiated (e.g., "h2", "http/1.1")
    alpn_negotiated_protocol: ?[]const u8 = null,
};

// =============================================================================
// Tests
// =============================================================================

test "MockBackend - basic request/response" {
    const allocator = std.testing.allocator;

    const mock = MockBackend.init(allocator);
    defer mock.deinit();

    // Add a canned response
    try mock.addResponse("https://example.com/api", .{
        .status = 200,
        .headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
        .body = "{\"ok\": true}",
    });

    const backend_iface = mock.backend();

    // Make a request
    const request = NetworkRequest{
        .url = "https://example.com/api",
        .method = "GET",
        .headers = &.{},
        .body = null,
    };

    var response = try backend_iface.send(allocator, &request);
    defer response.deinit();

    try std.testing.expectEqual(@as(u16, 200), response.status);
    try std.testing.expectEqualStrings("{\"ok\": true}", response.body.?);
    try std.testing.expectEqual(@as(usize, 1), response.headers.len);
    try std.testing.expectEqualStrings("Content-Type", response.headers[0].name);
}

test "MockBackend - request history" {
    const allocator = std.testing.allocator;

    const mock = MockBackend.init(allocator);
    defer mock.deinit();

    mock.setDefaultResponse(.{ .status = 200 });

    const backend_iface = mock.backend();

    // Make requests
    const request1 = NetworkRequest{
        .url = "https://example.com/a",
        .method = "GET",
        .headers = &.{},
        .body = null,
    };
    var response1 = try backend_iface.send(allocator, &request1);
    defer response1.deinit();

    const request2 = NetworkRequest{
        .url = "https://example.com/b",
        .method = "POST",
        .headers = &.{.{ .name = "Content-Type", .value = "text/plain" }},
        .body = "hello",
    };
    var response2 = try backend_iface.send(allocator, &request2);
    defer response2.deinit();

    // Check history
    const history = mock.getRequestHistory();
    try std.testing.expectEqual(@as(usize, 2), history.len);
    try std.testing.expectEqualStrings("https://example.com/a", history[0].url);
    try std.testing.expectEqualStrings("GET", history[0].method);
    try std.testing.expectEqualStrings("https://example.com/b", history[1].url);
    try std.testing.expectEqualStrings("POST", history[1].method);
    try std.testing.expectEqualStrings("hello", history[1].body.?);
}

test "MockBackend - forced error" {
    const allocator = std.testing.allocator;

    const mock = MockBackend.init(allocator);
    defer mock.deinit();

    mock.setForceError(NetworkError.ConnectionRefused);

    const backend_iface = mock.backend();

    const request = NetworkRequest{
        .url = "https://example.com/api",
        .method = "GET",
        .headers = &.{},
        .body = null,
    };

    const result = backend_iface.send(allocator, &request);
    try std.testing.expectError(NetworkError.ConnectionRefused, result);
}

test "MockBackend - abort" {
    const allocator = std.testing.allocator;

    const mock = MockBackend.init(allocator);
    defer mock.deinit();

    mock.setDefaultResponse(.{ .status = 200 });

    const backend_iface = mock.backend();

    // Abort before request
    backend_iface.abort();

    const request = NetworkRequest{
        .url = "https://example.com/api",
        .method = "GET",
        .headers = &.{},
        .body = null,
    };

    const result = backend_iface.send(allocator, &request);
    try std.testing.expectError(NetworkError.Aborted, result);
}

test "MockBackend - default 404 response" {
    const allocator = std.testing.allocator;

    const mock = MockBackend.init(allocator);
    defer mock.deinit();

    const backend_iface = mock.backend();

    const request = NetworkRequest{
        .url = "https://example.com/nonexistent",
        .method = "GET",
        .headers = &.{},
        .body = null,
    };

    var response = try backend_iface.send(allocator, &request);
    defer response.deinit();

    try std.testing.expectEqual(@as(u16, 404), response.status);
}

test "MockBackend - backend name" {
    const allocator = std.testing.allocator;

    const mock = MockBackend.init(allocator);
    defer mock.deinit();

    const backend_iface = mock.backend();
    try std.testing.expectEqualStrings("MockBackend", backend_iface.getName());
}

test "NetworkResponse - deinit frees memory" {
    const allocator = std.testing.allocator;

    var headers = try allocator.alloc(NetworkResponse.Header, 1);
    headers[0] = .{
        .name = try allocator.dupe(u8, "X-Test"),
        .value = try allocator.dupe(u8, "value"),
    };

    var response = NetworkResponse{
        .allocator = allocator,
        .status = 200,
        .http_version = .http_1_1,
        .headers = headers,
        .body = try allocator.dupe(u8, "test body"),
        .final_url = try allocator.dupe(u8, "https://final.com"),
        .total_time_ms = 100,
        .time_to_first_byte_ms = 50,
        .redirect_count = 0,
        .remote_ip = try allocator.dupe(u8, "127.0.0.1"),
        .remote_port = 443,
    };

    response.deinit();
    // If no leak, test passes
}

test "HttpVersion - toString" {
    try std.testing.expectEqualStrings("HTTP/1.0", HttpVersion.http_1_0.toString());
    try std.testing.expectEqualStrings("HTTP/1.1", HttpVersion.http_1_1.toString());
    try std.testing.expectEqualStrings("HTTP/2", HttpVersion.http_2.toString());
    try std.testing.expectEqualStrings("HTTP/3", HttpVersion.http_3.toString());
}
