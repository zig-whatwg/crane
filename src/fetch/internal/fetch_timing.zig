//! WHATWG Fetch Standard - Fetch Timing Info
//!
//! This module implements timing-related structs for Resource Timing and Navigation Timing.
//!
//! Spec: https://fetch.spec.whatwg.org/#fetch-timing-info
//!
//! These structs maintain timing information needed by:
//! - Resource Timing API (PerformanceResourceTiming)
//! - Navigation Timing API (PerformanceNavigationTiming)

const std = @import("std");
const Allocator = std.mem.Allocator;

/// DOMHighResTimeStamp type (milliseconds with sub-millisecond precision).
/// Per spec, this is a floating-point value representing time in milliseconds.
pub const DOMHighResTimeStamp = f64;

/// Connection timing info for network connection establishment.
///
/// Per spec (https://fetch.spec.whatwg.org/#connection-timing-info):
/// A connection timing info is a struct used to maintain timing information
/// pertaining to the process of obtaining a connection.
pub const ConnectionTimingInfo = struct {
    /// DNS lookup start time (DOMHighResTimeStamp).
    /// Time immediately before DNS lookup starts.
    domain_lookup_start_time: DOMHighResTimeStamp = 0,

    /// DNS lookup end time (DOMHighResTimeStamp).
    /// Time immediately after DNS lookup completes.
    domain_lookup_end_time: DOMHighResTimeStamp = 0,

    /// TCP connection start time (DOMHighResTimeStamp).
    /// Time immediately before the user agent starts establishing connection.
    connection_start_time: DOMHighResTimeStamp = 0,

    /// TCP connection end time (DOMHighResTimeStamp).
    /// Time immediately after the user agent finishes establishing connection.
    /// For HTTP/3, this equals secure_connection_start_time.
    connection_end_time: DOMHighResTimeStamp = 0,

    /// TLS handshake start time (DOMHighResTimeStamp).
    /// Time immediately before the TLS handshake starts.
    /// 0 if not using HTTPS.
    secure_connection_start_time: DOMHighResTimeStamp = 0,

    /// ALPN negotiated protocol (e.g., "h2", "h3", "http/1.1").
    /// Per RFC 7301, this is the protocol identifier.
    alpn_negotiated_protocol: []const u8 = "",

    const Self = @This();

    /// Create a new ConnectionTimingInfo with default values.
    pub fn init() Self {
        return .{};
    }

    /// Create a ConnectionTimingInfo for a reused connection.
    /// All timing values are set to the default start time.
    pub fn forReusedConnection(default_start_time: DOMHighResTimeStamp) Self {
        return .{
            .domain_lookup_start_time = default_start_time,
            .domain_lookup_end_time = default_start_time,
            .connection_start_time = default_start_time,
            .connection_end_time = default_start_time,
            .secure_connection_start_time = default_start_time,
        };
    }
};

/// Response body info for Resource Timing.
///
/// Per spec (https://fetch.spec.whatwg.org/#response-body-info):
/// A response body info is a struct used to maintain information needed by
/// Resource Timing and Navigation Timing.
pub const ResponseBodyInfo = struct {
    /// Encoded (compressed) size in bytes.
    /// This is the size of the response body before decompression.
    encoded_size: u64 = 0,

    /// Decoded (uncompressed) size in bytes.
    /// This is the size of the response body after decompression.
    decoded_size: u64 = 0,

    /// Content-Type header value (ASCII string).
    content_type: []const u8 = "",

    /// Content-Encoding header value (ASCII string).
    /// E.g., "gzip", "br", "deflate", or empty string.
    content_encoding: []const u8 = "",

    const Self = @This();

    /// Create a new ResponseBodyInfo with default values.
    pub fn init() Self {
        return .{};
    }
};

/// Fetch timing info maintains timing information needed by Resource Timing
/// and Navigation Timing specs.
///
/// Per spec (https://fetch.spec.whatwg.org/#fetch-timing-info):
/// A fetch timing info is a struct used to maintain timing information needed
/// by Resource Timing and Navigation Timing.
pub const FetchTimingInfo = struct {
    allocator: Allocator,

    /// Start time of the fetch (DOMHighResTimeStamp).
    /// Time immediately before the user agent starts fetching the resource.
    start_time: DOMHighResTimeStamp = 0,

    /// Time when redirect processing started (DOMHighResTimeStamp).
    /// 0 if no redirects occurred.
    redirect_start_time: DOMHighResTimeStamp = 0,

    /// Time when redirect processing ended (DOMHighResTimeStamp).
    /// 0 if no redirects occurred.
    redirect_end_time: DOMHighResTimeStamp = 0,

    /// Start time after any redirects (DOMHighResTimeStamp).
    /// For requests without redirects, equals start_time.
    post_redirect_start_time: DOMHighResTimeStamp = 0,

    /// When final service worker started processing (DOMHighResTimeStamp).
    /// 0 if no service worker handled the request.
    final_service_worker_start_time: DOMHighResTimeStamp = 0,

    /// When final network request started (DOMHighResTimeStamp).
    final_network_request_start_time: DOMHighResTimeStamp = 0,

    /// When first interim network response arrived (DOMHighResTimeStamp).
    /// E.g., time of 1xx informational response.
    first_interim_network_response_start_time: DOMHighResTimeStamp = 0,

    /// When final network response started (DOMHighResTimeStamp).
    final_network_response_start_time: DOMHighResTimeStamp = 0,

    /// End time of the fetch (DOMHighResTimeStamp).
    end_time: DOMHighResTimeStamp = 0,

    /// Connection timing info (null until connection established).
    final_connection_timing_info: ?ConnectionTimingInfo = null,

    /// List of Server-Timing header values.
    /// Per spec: "A list of strings."
    server_timing_headers: std.ArrayListUnmanaged([]const u8),

    /// Whether fetch is render-blocking.
    /// Per spec: "A boolean."
    render_blocking: bool = false,

    const Self = @This();

    /// Initialize a new FetchTimingInfo.
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .server_timing_headers = .{},
        };
    }

    /// Deinitialize and free resources.
    pub fn deinit(self: *Self) void {
        self.server_timing_headers.deinit(self.allocator);
    }

    /// Add a Server-Timing header value.
    pub fn addServerTimingHeader(self: *Self, header: []const u8) !void {
        try self.server_timing_headers.append(self.allocator, header);
    }

    /// Set the final connection timing info.
    pub fn setConnectionTimingInfo(self: *Self, info: ConnectionTimingInfo) void {
        self.final_connection_timing_info = info;
    }

    /// Record redirect timing.
    /// Called when a redirect is followed.
    pub fn recordRedirect(self: *Self, redirect_start: DOMHighResTimeStamp, redirect_end: DOMHighResTimeStamp) void {
        if (self.redirect_start_time == 0) {
            self.redirect_start_time = redirect_start;
        }
        self.redirect_end_time = redirect_end;
    }
};

/// Create an opaque timing info for cross-origin responses.
///
/// Per spec (https://fetch.spec.whatwg.org/#create-an-opaque-timing-info):
/// To create an opaque timing info, given a fetch timing info timingInfo,
/// return a new fetch timing info whose start time and post-redirect start time
/// are timingInfo's start time.
///
/// This is used to hide timing details for cross-origin responses that don't
/// pass timing-allow checks.
pub fn createOpaqueTimingInfo(allocator: std.mem.Allocator, timing_info: *const FetchTimingInfo) FetchTimingInfo {
    var result = FetchTimingInfo.init(allocator);
    result.start_time = timing_info.start_time;
    result.post_redirect_start_time = timing_info.start_time;
    return result;
}

/// Coarsen time for privacy.
///
/// Per spec, time values should be coarsened to reduce timing attack surface.
/// Cross-origin-isolated contexts get higher precision.
///
/// Parameters:
/// - time: The timestamp to coarsen
/// - cross_origin_isolated: Whether the context is cross-origin isolated
///
/// Returns: Coarsened timestamp
pub fn coarsenTime(time: DOMHighResTimeStamp, cross_origin_isolated: bool) DOMHighResTimeStamp {
    // Per spec, cross-origin-isolated contexts can have higher precision
    // Non-isolated contexts are coarsened to 100 microseconds (0.1 ms)
    // Isolated contexts are coarsened to 5 microseconds (0.005 ms)
    const resolution: DOMHighResTimeStamp = if (cross_origin_isolated) 0.005 else 0.1;

    // Round down to resolution
    return @floor(time / resolution) * resolution;
}

/// Clamp and coarsen connection timing info for security.
///
/// Per spec (https://fetch.spec.whatwg.org/#clamp-and-coarsen-connection-timing-info):
/// To clamp and coarsen connection timing info, given a connection timing info
/// timingInfo, a DOMHighResTimeStamp defaultStartTime, and a boolean
/// crossOriginIsolatedCapability:
///
/// 1. If timingInfo's connection start time is less than defaultStartTime,
///    return a new connection timing info with all times set to defaultStartTime.
/// 2. Otherwise, coarsen each time based on cross-origin-isolated capability.
pub fn clampAndCoarsenConnectionTimingInfo(
    timing_info: *const ConnectionTimingInfo,
    default_start_time: DOMHighResTimeStamp,
    cross_origin_isolated: bool,
) ConnectionTimingInfo {
    // Step 1: If connection was reused (start time < default), return clamped values
    if (timing_info.connection_start_time < default_start_time) {
        return .{
            .domain_lookup_start_time = default_start_time,
            .domain_lookup_end_time = default_start_time,
            .connection_start_time = default_start_time,
            .connection_end_time = default_start_time,
            .secure_connection_start_time = default_start_time,
            .alpn_negotiated_protocol = timing_info.alpn_negotiated_protocol,
        };
    }

    // Step 2: Coarsen all timing values
    return .{
        .domain_lookup_start_time = coarsenTime(timing_info.domain_lookup_start_time, cross_origin_isolated),
        .domain_lookup_end_time = coarsenTime(timing_info.domain_lookup_end_time, cross_origin_isolated),
        .connection_start_time = coarsenTime(timing_info.connection_start_time, cross_origin_isolated),
        .connection_end_time = coarsenTime(timing_info.connection_end_time, cross_origin_isolated),
        .secure_connection_start_time = coarsenTime(timing_info.secure_connection_start_time, cross_origin_isolated),
        .alpn_negotiated_protocol = timing_info.alpn_negotiated_protocol,
    };
}

// =============================================================================
// Tests
// =============================================================================

test "ConnectionTimingInfo default initialization" {
    const info = ConnectionTimingInfo.init();

    try std.testing.expectEqual(@as(DOMHighResTimeStamp, 0), info.domain_lookup_start_time);
    try std.testing.expectEqual(@as(DOMHighResTimeStamp, 0), info.connection_start_time);
    try std.testing.expectEqual(@as(DOMHighResTimeStamp, 0), info.secure_connection_start_time);
    try std.testing.expectEqualStrings("", info.alpn_negotiated_protocol);
}

test "ConnectionTimingInfo for reused connection" {
    const default_time: DOMHighResTimeStamp = 1000.5;
    const info = ConnectionTimingInfo.forReusedConnection(default_time);

    try std.testing.expectEqual(default_time, info.domain_lookup_start_time);
    try std.testing.expectEqual(default_time, info.domain_lookup_end_time);
    try std.testing.expectEqual(default_time, info.connection_start_time);
    try std.testing.expectEqual(default_time, info.connection_end_time);
    try std.testing.expectEqual(default_time, info.secure_connection_start_time);
}

test "ResponseBodyInfo default initialization" {
    const info = ResponseBodyInfo.init();

    try std.testing.expectEqual(@as(u64, 0), info.encoded_size);
    try std.testing.expectEqual(@as(u64, 0), info.decoded_size);
    try std.testing.expectEqualStrings("", info.content_type);
    try std.testing.expectEqualStrings("", info.content_encoding);
}

test "FetchTimingInfo initialization and deinit" {
    const allocator = std.testing.allocator;

    var info = FetchTimingInfo.init(allocator);
    defer info.deinit();

    try std.testing.expectEqual(@as(DOMHighResTimeStamp, 0), info.start_time);
    try std.testing.expectEqual(@as(DOMHighResTimeStamp, 0), info.redirect_start_time);
    try std.testing.expectEqual(false, info.render_blocking);
    try std.testing.expect(info.final_connection_timing_info == null);
    try std.testing.expectEqual(@as(usize, 0), info.server_timing_headers.items.len);
}

test "FetchTimingInfo server timing headers" {
    const allocator = std.testing.allocator;

    var info = FetchTimingInfo.init(allocator);
    defer info.deinit();

    try info.addServerTimingHeader("cache;desc=\"Cache Read\"");
    try info.addServerTimingHeader("db;dur=53");

    try std.testing.expectEqual(@as(usize, 2), info.server_timing_headers.items.len);
    try std.testing.expectEqualStrings("cache;desc=\"Cache Read\"", info.server_timing_headers.items[0]);
    try std.testing.expectEqualStrings("db;dur=53", info.server_timing_headers.items[1]);
}

test "FetchTimingInfo redirect recording" {
    const allocator = std.testing.allocator;

    var info = FetchTimingInfo.init(allocator);
    defer info.deinit();

    // First redirect
    info.recordRedirect(100.0, 150.0);
    try std.testing.expectEqual(@as(DOMHighResTimeStamp, 100.0), info.redirect_start_time);
    try std.testing.expectEqual(@as(DOMHighResTimeStamp, 150.0), info.redirect_end_time);

    // Second redirect - start time shouldn't change, end time should update
    info.recordRedirect(150.0, 200.0);
    try std.testing.expectEqual(@as(DOMHighResTimeStamp, 100.0), info.redirect_start_time);
    try std.testing.expectEqual(@as(DOMHighResTimeStamp, 200.0), info.redirect_end_time);
}

test "FetchTimingInfo connection timing info" {
    const allocator = std.testing.allocator;

    var info = FetchTimingInfo.init(allocator);
    defer info.deinit();

    const conn_info = ConnectionTimingInfo{
        .domain_lookup_start_time = 10.0,
        .domain_lookup_end_time = 20.0,
        .connection_start_time = 20.0,
        .connection_end_time = 50.0,
        .secure_connection_start_time = 30.0,
        .alpn_negotiated_protocol = "h2",
    };

    info.setConnectionTimingInfo(conn_info);

    try std.testing.expect(info.final_connection_timing_info != null);
    try std.testing.expectEqual(@as(DOMHighResTimeStamp, 10.0), info.final_connection_timing_info.?.domain_lookup_start_time);
    try std.testing.expectEqualStrings("h2", info.final_connection_timing_info.?.alpn_negotiated_protocol);
}

test "createOpaqueTimingInfo preserves only start time" {
    const allocator = std.testing.allocator;

    var original = FetchTimingInfo.init(allocator);
    defer original.deinit();

    original.start_time = 100.0;
    original.redirect_start_time = 100.0;
    original.redirect_end_time = 150.0;
    original.post_redirect_start_time = 150.0;
    original.final_network_request_start_time = 160.0;
    original.final_network_response_start_time = 200.0;
    original.end_time = 250.0;

    var opaque_info = createOpaqueTimingInfo(allocator, &original);
    defer opaque_info.deinit();

    // Only start_time and post_redirect_start_time should be preserved
    // (both set to original's start_time)
    try std.testing.expectEqual(@as(DOMHighResTimeStamp, 100.0), opaque_info.start_time);
    try std.testing.expectEqual(@as(DOMHighResTimeStamp, 100.0), opaque_info.post_redirect_start_time);

    // All other timing should be 0
    try std.testing.expectEqual(@as(DOMHighResTimeStamp, 0), opaque_info.redirect_start_time);
    try std.testing.expectEqual(@as(DOMHighResTimeStamp, 0), opaque_info.redirect_end_time);
    try std.testing.expectEqual(@as(DOMHighResTimeStamp, 0), opaque_info.final_network_request_start_time);
    try std.testing.expectEqual(@as(DOMHighResTimeStamp, 0), opaque_info.end_time);
}

test "coarsenTime non-isolated context" {
    // Non-isolated: 0.1ms (100 microsecond) resolution
    const coarsened = coarsenTime(123.456789, false);

    // Should be rounded down to 0.1ms precision
    // 123.456789 -> 123.4
    try std.testing.expectApproxEqAbs(@as(DOMHighResTimeStamp, 123.4), coarsened, 0.0001);
}

test "coarsenTime isolated context" {
    // Isolated: 0.005ms (5 microsecond) resolution
    const coarsened = coarsenTime(123.456789, true);

    // Should be rounded down to 0.005ms precision
    // 123.456789 -> 123.455
    try std.testing.expectApproxEqAbs(@as(DOMHighResTimeStamp, 123.455), coarsened, 0.0001);
}

test "clampAndCoarsenConnectionTimingInfo with new connection" {
    const conn_info = ConnectionTimingInfo{
        .domain_lookup_start_time = 100.123,
        .domain_lookup_end_time = 110.456,
        .connection_start_time = 110.456,
        .connection_end_time = 150.789,
        .secure_connection_start_time = 120.321,
        .alpn_negotiated_protocol = "h2",
    };

    const default_start: DOMHighResTimeStamp = 50.0;

    // New connection (start time > default start) - should coarsen
    const result = clampAndCoarsenConnectionTimingInfo(&conn_info, default_start, false);

    // Values should be coarsened (non-isolated = 0.1ms resolution)
    try std.testing.expectApproxEqAbs(@as(DOMHighResTimeStamp, 100.1), result.domain_lookup_start_time, 0.0001);
    try std.testing.expectApproxEqAbs(@as(DOMHighResTimeStamp, 110.4), result.domain_lookup_end_time, 0.0001);
    try std.testing.expectEqualStrings("h2", result.alpn_negotiated_protocol);
}

test "clampAndCoarsenConnectionTimingInfo with reused connection" {
    const conn_info = ConnectionTimingInfo{
        .domain_lookup_start_time = 10.0,
        .domain_lookup_end_time = 20.0,
        .connection_start_time = 20.0, // Less than default_start
        .connection_end_time = 50.0,
        .secure_connection_start_time = 30.0,
        .alpn_negotiated_protocol = "h2",
    };

    const default_start: DOMHighResTimeStamp = 100.0;

    // Reused connection (start time < default start) - should clamp
    const result = clampAndCoarsenConnectionTimingInfo(&conn_info, default_start, false);

    // All timing values should be clamped to default_start
    try std.testing.expectEqual(default_start, result.domain_lookup_start_time);
    try std.testing.expectEqual(default_start, result.domain_lookup_end_time);
    try std.testing.expectEqual(default_start, result.connection_start_time);
    try std.testing.expectEqual(default_start, result.connection_end_time);
    try std.testing.expectEqual(default_start, result.secure_connection_start_time);
    // Protocol should still be preserved
    try std.testing.expectEqualStrings("h2", result.alpn_negotiated_protocol);
}
