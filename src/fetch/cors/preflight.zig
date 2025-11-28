//! CORS Preflight Algorithm
//!
//! Spec: https://fetch.spec.whatwg.org/#cors-preflight-fetch
//!
//! This module implements CORS preflight request generation and validation.

const std = @import("std");
const Allocator = std.mem.Allocator;
const check = @import("check.zig");
const CredentialsMode = check.CredentialsMode;

/// Preflight request information.
///
/// Contains all the data needed to perform a CORS preflight request.
pub const PreflightRequest = struct {
    allocator: Allocator,

    /// The origin making the request
    origin: []const u8,

    /// Target URL for the preflight
    url: []const u8,

    /// The actual request method (for Access-Control-Request-Method)
    request_method: []const u8,

    /// Unsafe header names (for Access-Control-Request-Headers)
    request_headers: ?[]const u8,

    /// Free owned memory.
    pub fn deinit(self: *PreflightRequest) void {
        self.allocator.free(self.origin);
        self.allocator.free(self.url);
        self.allocator.free(self.request_method);
        if (self.request_headers) |h| {
            self.allocator.free(h);
        }
    }
};

/// Result of preflight validation.
pub const PreflightResult = union(enum) {
    /// Preflight succeeded, proceed with actual request
    success: PreflightCacheEntry,

    /// Preflight failed with error
    failure: PreflightError,
};

/// Error from preflight validation.
pub const PreflightError = enum {
    /// CORS check failed (bad Access-Control-Allow-Origin)
    cors_check_failed,

    /// HTTP status was not 2xx
    http_error,

    /// Method not in Access-Control-Allow-Methods
    method_not_allowed,

    /// Header not in Access-Control-Allow-Headers
    header_not_allowed,

    /// Wildcard used with credentials mode
    wildcard_with_credentials,

    /// Missing required header
    missing_header,
};

/// Entry for the preflight cache.
pub const PreflightCacheEntry = struct {
    allocator: Allocator,

    /// Allowed methods from response
    methods: std.ArrayListUnmanaged([]const u8),

    /// Allowed headers from response
    headers: std.ArrayListUnmanaged([]const u8),

    /// Whether wildcard (*) was used for methods
    methods_wildcard: bool,

    /// Whether wildcard (*) was used for headers
    headers_wildcard: bool,

    /// Cache expiry time (Unix timestamp)
    expiry_time: i64,

    /// Free owned memory.
    pub fn deinit(self: *PreflightCacheEntry) void {
        for (self.methods.items) |m| {
            self.allocator.free(m);
        }
        self.methods.deinit(self.allocator);

        for (self.headers.items) |h| {
            self.allocator.free(h);
        }
        self.headers.deinit(self.allocator);
    }
};

/// Create a preflight request for the given actual request.
///
/// Spec: https://fetch.spec.whatwg.org/#cors-preflight-fetch Step 1-4
///
/// Parameters:
/// - allocator: For allocating the preflight request data
/// - url: The URL for the actual request
/// - origin: The origin making the request
/// - method: The actual request method
/// - unsafe_headers: List of unsafe header names (or null if none)
pub fn createPreflightRequest(
    allocator: Allocator,
    url: []const u8,
    origin: []const u8,
    method: []const u8,
    unsafe_headers: ?[]const []const u8,
) !PreflightRequest {
    const owned_url = try allocator.dupe(u8, url);
    errdefer allocator.free(owned_url);

    const owned_origin = try allocator.dupe(u8, origin);
    errdefer allocator.free(owned_origin);

    const owned_method = try allocator.dupe(u8, method);
    errdefer allocator.free(owned_method);

    var headers_value: ?[]const u8 = null;
    if (unsafe_headers) |hdrs| {
        if (hdrs.len > 0) {
            // Join headers with ", "
            var total_len: usize = 0;
            for (hdrs) |h| {
                total_len += h.len;
            }
            total_len += (hdrs.len - 1) * 2; // ", " separators

            var buf = try allocator.alloc(u8, total_len);
            var pos: usize = 0;
            for (hdrs, 0..) |h, i| {
                @memcpy(buf[pos..][0..h.len], h);
                pos += h.len;
                if (i < hdrs.len - 1) {
                    buf[pos] = ',';
                    buf[pos + 1] = ' ';
                    pos += 2;
                }
            }
            headers_value = buf;
        }
    }

    return .{
        .allocator = allocator,
        .url = owned_url,
        .origin = owned_origin,
        .request_method = owned_method,
        .request_headers = headers_value,
    };
}

/// Validate a preflight response.
///
/// Spec: https://fetch.spec.whatwg.org/#cors-preflight-fetch Steps 6-12
///
/// Parameters:
/// - allocator: For allocating cache entry
/// - origin: The origin that made the request
/// - method: The actual request method
/// - unsafe_headers: Unsafe headers from actual request
/// - credentials_mode: Whether credentials will be included
/// - response_headers: Headers from the preflight response
/// - response_status: HTTP status code from preflight response
pub fn validatePreflightResponse(
    allocator: Allocator,
    origin: []const u8,
    method: []const u8,
    unsafe_headers: ?[]const []const u8,
    credentials_mode: CredentialsMode,
    response_headers: anytype,
    response_status: u16,
) PreflightResult {
    // Step 6: CORS check
    const cors_result = check.corsCheck(origin, credentials_mode, response_headers);
    if (cors_result == .failure) {
        return .{ .failure = .cors_check_failed };
    }

    // Step 7: Check HTTP status (must be 2xx)
    if (response_status < 200 or response_status >= 300) {
        return .{ .failure = .http_error };
    }

    // Step 8: Parse allowed methods
    const methods_result = parseAllowedValues(allocator, response_headers, "Access-Control-Allow-Methods") catch {
        return .{ .failure = .missing_header };
    };
    var allowed_methods = methods_result.values;
    const methods_wildcard = methods_result.has_wildcard;

    // Step 9: Check if method is allowed
    if (!isMethodAllowed(method, allowed_methods.items, methods_wildcard, credentials_mode)) {
        for (allowed_methods.items) |m| {
            allocator.free(m);
        }
        allowed_methods.deinit(allocator);
        return .{ .failure = .method_not_allowed };
    }

    // Parse allowed headers
    const headers_result = parseAllowedValues(allocator, response_headers, "Access-Control-Allow-Headers") catch {
        for (allowed_methods.items) |m| {
            allocator.free(m);
        }
        allowed_methods.deinit(allocator);
        return .{ .failure = .missing_header };
    };
    var allowed_headers = headers_result.values;
    const headers_wildcard = headers_result.has_wildcard;

    // Step 10: Check if all unsafe headers are allowed
    if (unsafe_headers) |hdrs| {
        if (!areHeadersAllowed(hdrs, allowed_headers.items, headers_wildcard, credentials_mode)) {
            for (allowed_methods.items) |m| {
                allocator.free(m);
            }
            allowed_methods.deinit(allocator);
            for (allowed_headers.items) |h| {
                allocator.free(h);
            }
            allowed_headers.deinit(allocator);
            return .{ .failure = .header_not_allowed };
        }
    }

    // Step 11: Check for wildcard with credentials
    if (credentials_mode == .include) {
        if (methods_wildcard or headers_wildcard) {
            for (allowed_methods.items) |m| {
                allocator.free(m);
            }
            allowed_methods.deinit(allocator);
            for (allowed_headers.items) |h| {
                allocator.free(h);
            }
            allowed_headers.deinit(allocator);
            return .{ .failure = .wildcard_with_credentials };
        }
    }

    // Step 12: Parse max-age and create cache entry
    const max_age = parseMaxAge(response_headers);
    const expiry_time = std.time.timestamp() + @as(i64, @intCast(max_age));

    return .{
        .success = .{
            .allocator = allocator,
            .methods = allowed_methods,
            .headers = allowed_headers,
            .methods_wildcard = methods_wildcard,
            .headers_wildcard = headers_wildcard,
            .expiry_time = expiry_time,
        },
    };
}

/// Result of parsing allowed values.
const ParsedValues = struct {
    values: std.ArrayListUnmanaged([]const u8),
    has_wildcard: bool,
};

/// Parse Access-Control-Allow-Methods or Access-Control-Allow-Headers.
fn parseAllowedValues(
    allocator: Allocator,
    headers: anytype,
    header_name: []const u8,
) !ParsedValues {
    var values: std.ArrayListUnmanaged([]const u8) = .{};
    errdefer {
        for (values.items) |v| {
            allocator.free(v);
        }
        values.deinit(allocator);
    }

    var has_wildcard = false;

    const header_value = headers.get(header_name) orelse return .{
        .values = values,
        .has_wildcard = false,
    };

    // Split on commas
    var iter = std.mem.splitScalar(u8, header_value, ',');
    while (iter.next()) |value| {
        const trimmed = std.mem.trim(u8, value, " \t");
        if (trimmed.len == 0) continue;

        if (std.mem.eql(u8, trimmed, "*")) {
            has_wildcard = true;
        }

        const owned = try allocator.dupe(u8, trimmed);
        try values.append(allocator, owned);
    }

    return .{
        .values = values,
        .has_wildcard = has_wildcard,
    };
}

/// Parse Access-Control-Max-Age header.
///
/// Returns max-age in seconds. Defaults to 5 seconds if not present or invalid.
/// Maximum is typically capped by browsers (e.g., 7200 seconds in Chrome).
fn parseMaxAge(headers: anytype) u64 {
    const value = headers.get("Access-Control-Max-Age") orelse return 5;
    return std.fmt.parseInt(u64, value, 10) catch 5;
}

/// Check if a method is allowed.
///
/// Note: This allows methods when wildcard is present even with credentials.
/// The credentials+wildcard check is done separately in step 11.
fn isMethodAllowed(
    method: []const u8,
    allowed: []const []const u8,
    has_wildcard: bool,
    credentials_mode: CredentialsMode,
) bool {
    _ = credentials_mode; // Checked separately in step 11

    // Wildcard allows any method
    if (has_wildcard) {
        return true;
    }

    // CORS-safelisted methods are always allowed (GET, HEAD, POST)
    if (check.isCorseSafelistedMethod(method)) {
        return true;
    }

    // Check if method is in allowed list
    for (allowed) |m| {
        if (eqlIgnoreCase(m, method)) {
            return true;
        }
    }

    return false;
}

/// Check if all headers are allowed.
///
/// Note: This allows headers when wildcard is present even with credentials.
/// The credentials+wildcard check is done separately in step 11.
fn areHeadersAllowed(
    requested: []const []const u8,
    allowed: []const []const u8,
    has_wildcard: bool,
    credentials_mode: CredentialsMode,
) bool {
    _ = credentials_mode; // Checked separately in step 11

    // Wildcard allows any header
    // But Authorization header requires explicit listing even with wildcard
    if (has_wildcard) {
        // Check for Authorization header which needs explicit listing
        for (requested) |h| {
            if (eqlIgnoreCase(h, "Authorization")) {
                var found = false;
                for (allowed) |a| {
                    if (eqlIgnoreCase(a, "Authorization")) {
                        found = true;
                        break;
                    }
                }
                if (!found) return false;
            }
        }
        return true;
    }

    // Check each requested header
    for (requested) |header| {
        var found = false;
        for (allowed) |a| {
            if (eqlIgnoreCase(a, header)) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }

    return true;
}

/// Get CORS-unsafe request header names.
///
/// Returns a list of header names that are not CORS-safelisted.
pub fn getCorsUnsafeHeaderNames(
    allocator: Allocator,
    header_names: []const []const u8,
    header_values: []const []const u8,
) ![]const []const u8 {
    var result: std.ArrayListUnmanaged([]const u8) = .{};
    errdefer result.deinit(allocator);

    for (header_names, header_values) |name, value| {
        if (!check.isCorseSafelistedRequestHeader(name, value)) {
            // Check if already in list
            var exists = false;
            for (result.items) |existing| {
                if (eqlIgnoreCase(existing, name)) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                try result.append(allocator, name);
            }
        }
    }

    return result.toOwnedSlice(allocator);
}

fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (std.ascii.toLower(ca) != std.ascii.toLower(cb)) {
            return false;
        }
    }
    return true;
}

// =============================================================================
// Tests
// =============================================================================

/// Mock header list for testing.
const MockHeaders = struct {
    headers: std.StringHashMap([]const u8),

    pub fn init(allocator: Allocator) MockHeaders {
        return .{ .headers = std.StringHashMap([]const u8).init(allocator) };
    }

    pub fn deinit(self: *MockHeaders) void {
        self.headers.deinit();
    }

    pub fn put(self: *MockHeaders, name: []const u8, value: []const u8) !void {
        try self.headers.put(name, value);
    }

    pub fn get(self: *const MockHeaders, name: []const u8) ?[]const u8 {
        return self.headers.get(name);
    }
};

test "createPreflightRequest basic" {
    const allocator = std.testing.allocator;

    var request = try createPreflightRequest(
        allocator,
        "https://api.example.com/data",
        "https://example.com",
        "PUT",
        null,
    );
    defer request.deinit();

    try std.testing.expectEqualStrings("https://api.example.com/data", request.url);
    try std.testing.expectEqualStrings("https://example.com", request.origin);
    try std.testing.expectEqualStrings("PUT", request.request_method);
    try std.testing.expect(request.request_headers == null);
}

test "createPreflightRequest with unsafe headers" {
    const allocator = std.testing.allocator;

    const headers = [_][]const u8{ "X-Custom", "Authorization" };
    var request = try createPreflightRequest(
        allocator,
        "https://api.example.com/data",
        "https://example.com",
        "POST",
        &headers,
    );
    defer request.deinit();

    try std.testing.expectEqualStrings("X-Custom, Authorization", request.request_headers.?);
}

test "validatePreflightResponse success" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();
    try headers.put("Access-Control-Allow-Origin", "https://example.com");
    try headers.put("Access-Control-Allow-Methods", "GET, PUT, DELETE");
    try headers.put("Access-Control-Allow-Headers", "X-Custom");
    try headers.put("Access-Control-Max-Age", "3600");

    const unsafe = [_][]const u8{"X-Custom"};
    const result = validatePreflightResponse(
        allocator,
        "https://example.com",
        "PUT",
        &unsafe,
        .omit,
        headers,
        204,
    );

    switch (result) {
        .success => |*entry| {
            var cache = @constCast(entry);
            defer cache.deinit();
            try std.testing.expect(cache.methods.items.len >= 1);
        },
        .failure => |err| {
            std.debug.print("Unexpected failure: {}\n", .{err});
            return error.TestFailed;
        },
    }
}

test "validatePreflightResponse cors check failed" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();
    try headers.put("Access-Control-Allow-Origin", "https://other.com");
    try headers.put("Access-Control-Allow-Methods", "PUT");

    const result = validatePreflightResponse(
        allocator,
        "https://example.com",
        "PUT",
        null,
        .omit,
        headers,
        204,
    );

    try std.testing.expectEqual(PreflightResult{ .failure = .cors_check_failed }, result);
}

test "validatePreflightResponse http error" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();
    try headers.put("Access-Control-Allow-Origin", "https://example.com");

    const result = validatePreflightResponse(
        allocator,
        "https://example.com",
        "PUT",
        null,
        .omit,
        headers,
        403,
    );

    try std.testing.expectEqual(PreflightResult{ .failure = .http_error }, result);
}

test "validatePreflightResponse method not allowed" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();
    try headers.put("Access-Control-Allow-Origin", "https://example.com");
    try headers.put("Access-Control-Allow-Methods", "GET, POST");

    const result = validatePreflightResponse(
        allocator,
        "https://example.com",
        "DELETE",
        null,
        .omit,
        headers,
        204,
    );

    try std.testing.expectEqual(PreflightResult{ .failure = .method_not_allowed }, result);
}

test "validatePreflightResponse wildcard with credentials fails" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();
    try headers.put("Access-Control-Allow-Origin", "https://example.com");
    try headers.put("Access-Control-Allow-Credentials", "true");
    // Use explicit method listing so we get past method check
    // The wildcard is in headers which will trigger the error
    try headers.put("Access-Control-Allow-Methods", "PUT");
    try headers.put("Access-Control-Allow-Headers", "*");

    const unsafe = [_][]const u8{"X-Custom"};
    const result = validatePreflightResponse(
        allocator,
        "https://example.com",
        "PUT",
        &unsafe,
        .include,
        headers,
        204,
    );

    try std.testing.expectEqual(PreflightResult{ .failure = .wildcard_with_credentials }, result);
}

test "isMethodAllowed safelisted methods always allowed" {
    const methods = [_][]const u8{"PUT"};
    try std.testing.expect(isMethodAllowed("GET", &methods, false, .omit));
    try std.testing.expect(isMethodAllowed("HEAD", &methods, false, .omit));
    try std.testing.expect(isMethodAllowed("POST", &methods, false, .omit));
}

test "isMethodAllowed wildcard" {
    const methods = [_][]const u8{"*"};
    try std.testing.expect(isMethodAllowed("DELETE", &methods, true, .omit));
    // Wildcard still allows method; credentials check is done separately
    try std.testing.expect(isMethodAllowed("DELETE", &methods, true, .include));
}

test "parseMaxAge" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();

    // No header = default 5 seconds
    try std.testing.expectEqual(@as(u64, 5), parseMaxAge(headers));

    try headers.put("Access-Control-Max-Age", "3600");
    try std.testing.expectEqual(@as(u64, 3600), parseMaxAge(headers));
}

test "getCorsUnsafeHeaderNames" {
    const allocator = std.testing.allocator;

    const names = [_][]const u8{ "Accept", "Content-Type", "X-Custom", "Authorization" };
    const values = [_][]const u8{ "text/html", "application/json", "value", "Bearer token" };

    const unsafe = try getCorsUnsafeHeaderNames(allocator, &names, &values);
    defer allocator.free(unsafe);

    // Content-Type with application/json is not safelisted
    // X-Custom is not safelisted
    // Authorization is not safelisted
    try std.testing.expect(unsafe.len >= 2);
}
