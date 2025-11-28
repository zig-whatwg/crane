//! CORS Check Algorithm
//!
//! Spec: https://fetch.spec.whatwg.org/#concept-cors-check
//!
//! This module implements the CORS check and TAO (Timing-Allow-Origin) check
//! algorithms from the Fetch specification.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Credentials mode for requests.
pub const CredentialsMode = enum {
    /// Never send credentials (cookies, auth, client certs)
    omit,

    /// Send credentials for same-origin requests only
    same_origin,

    /// Always send credentials
    include,
};

/// Result of a CORS check.
pub const CorsCheckResult = enum {
    /// CORS check passed
    success,

    /// CORS check failed
    failure,
};

/// Perform CORS check on a response.
///
/// Spec: https://fetch.spec.whatwg.org/#concept-cors-check
///
/// Algorithm:
/// 1. Let origin be result of getting Access-Control-Allow-Origin from response headers
/// 2. If origin is null, return failure
/// 3. If request's credentials mode is not "include" and origin is "*", return success
/// 4. If origin is not byte-for-byte identical to request's origin serialized, return failure
/// 5. If request's credentials mode is not "include", return success
/// 6. Let credentials be result of getting Access-Control-Allow-Credentials from response
/// 7. If credentials is "true", return success
/// 8. Return failure
pub fn corsCheck(
    request_origin: []const u8,
    credentials_mode: CredentialsMode,
    response_headers: anytype,
) CorsCheckResult {
    // Step 1: Get Access-Control-Allow-Origin
    const allow_origin = response_headers.get("Access-Control-Allow-Origin") orelse {
        // Step 2: If origin is null, return failure
        return .failure;
    };

    // Step 3: Check for wildcard without credentials
    if (credentials_mode != .include and std.mem.eql(u8, allow_origin, "*")) {
        return .success;
    }

    // Step 4: Check exact origin match
    if (!std.mem.eql(u8, allow_origin, request_origin)) {
        return .failure;
    }

    // Step 5: If not include mode, success
    if (credentials_mode != .include) {
        return .success;
    }

    // Step 6-7: Check credentials header
    if (response_headers.get("Access-Control-Allow-Credentials")) |credentials| {
        if (std.mem.eql(u8, credentials, "true")) {
            return .success;
        }
    }

    // Step 8: Failure
    return .failure;
}

/// Result of a TAO check.
pub const TaoCheckResult = enum {
    /// TAO check passed
    success,

    /// TAO check failed
    failure,
};

/// Perform TAO (Timing-Allow-Origin) check.
///
/// Spec: https://fetch.spec.whatwg.org/#concept-tao-check
///
/// Algorithm:
/// 1. If request's timing allow failed flag is set, return failure
/// 2. Let values be result of getting, decoding, and splitting Timing-Allow-Origin
/// 3. If values is null, return failure
/// 4. If values contains "*" and credentials mode is not "include", return success
/// 5. If values contains serialization of request's origin, return success
/// 6. Return failure
pub fn taoCheck(
    request_origin: []const u8,
    credentials_mode: CredentialsMode,
    timing_allow_failed: bool,
    response_headers: anytype,
) TaoCheckResult {
    // Step 1: If timing allow failed flag is set, return failure
    if (timing_allow_failed) {
        return .failure;
    }

    // Step 2-3: Get Timing-Allow-Origin
    const tao_header = response_headers.get("Timing-Allow-Origin") orelse {
        return .failure;
    };

    // Parse comma-separated values
    var iter = std.mem.splitScalar(u8, tao_header, ',');
    while (iter.next()) |value| {
        const trimmed = std.mem.trim(u8, value, " \t");

        // Step 4: Check for wildcard without credentials
        if (std.mem.eql(u8, trimmed, "*") and credentials_mode != .include) {
            return .success;
        }

        // Step 5: Check if origin matches
        if (std.mem.eql(u8, trimmed, request_origin)) {
            return .success;
        }
    }

    // Step 6: Return failure
    return .failure;
}

/// Check if a method is a CORS-safelisted method.
///
/// Spec: https://fetch.spec.whatwg.org/#cors-safelisted-method
///
/// CORS-safelisted methods: GET, HEAD, POST
pub fn isCorseSafelistedMethod(method: []const u8) bool {
    return eqlIgnoreCase(method, "GET") or
        eqlIgnoreCase(method, "HEAD") or
        eqlIgnoreCase(method, "POST");
}

/// Check if a header is a CORS-safelisted request header.
///
/// Spec: https://fetch.spec.whatwg.org/#cors-safelisted-request-header
///
/// CORS-safelisted request headers have restrictions on:
/// - Name (must be Accept, Accept-Language, Content-Language, or Content-Type)
/// - Value (must meet specific criteria)
pub fn isCorseSafelistedRequestHeader(name: []const u8, value: []const u8) bool {
    if (eqlIgnoreCase(name, "Accept")) {
        return isSafeHeaderValue(value);
    }
    if (eqlIgnoreCase(name, "Accept-Language") or eqlIgnoreCase(name, "Content-Language")) {
        return isLanguageHeaderValue(value);
    }
    if (eqlIgnoreCase(name, "Content-Type")) {
        return isSafeContentType(value);
    }
    return false;
}

/// Check if a header name is a forbidden header name.
///
/// Spec: https://fetch.spec.whatwg.org/#forbidden-header-name
pub fn isForbiddenHeaderName(name: []const u8) bool {
    const forbidden = [_][]const u8{
        "Accept-Charset",
        "Accept-Encoding",
        "Access-Control-Request-Headers",
        "Access-Control-Request-Method",
        "Connection",
        "Content-Length",
        "Cookie",
        "Cookie2",
        "Date",
        "DNT",
        "Expect",
        "Host",
        "Keep-Alive",
        "Origin",
        "Referer",
        "Set-Cookie",
        "TE",
        "Trailer",
        "Transfer-Encoding",
        "Upgrade",
        "Via",
    };

    for (forbidden) |f| {
        if (eqlIgnoreCase(name, f)) return true;
    }

    // Proxy-* and Sec-* prefixes
    if (startsWithIgnoreCase(name, "Proxy-") or startsWithIgnoreCase(name, "Sec-")) {
        return true;
    }

    return false;
}

/// Check if a header name is a forbidden response header name.
///
/// Spec: https://fetch.spec.whatwg.org/#forbidden-response-header-name
pub fn isForbiddenResponseHeaderName(name: []const u8) bool {
    return eqlIgnoreCase(name, "Set-Cookie") or eqlIgnoreCase(name, "Set-Cookie2");
}

/// Check if a method is a forbidden method.
///
/// Spec: https://fetch.spec.whatwg.org/#forbidden-method
pub fn isForbiddenMethod(method: []const u8) bool {
    return eqlIgnoreCase(method, "CONNECT") or
        eqlIgnoreCase(method, "TRACE") or
        eqlIgnoreCase(method, "TRACK");
}

// === Helper functions ===

fn isSafeHeaderValue(value: []const u8) bool {
    // Safe if all bytes are in the allowed range and length <= 128
    if (value.len > 128) return false;
    for (value) |c| {
        // Allowed: 0x20-0x7E except for 0x22 ("), 0x28 ((), 0x29 ()), 0x3A (:),
        // 0x3C (<), 0x3E (>), 0x3F (?), 0x40 (@), 0x5B ([), 0x5C (\), 0x5D (]),
        // 0x7B ({), 0x7D (}), 0x7F (DEL)
        if (c < 0x20 or c > 0x7E) return false;
        if (c == '"' or c == '(' or c == ')' or c == ':' or
            c == '<' or c == '>' or c == '?' or c == '@' or
            c == '[' or c == '\\' or c == ']' or
            c == '{' or c == '}' or c == 0x7F) return false;
    }
    return true;
}

fn isLanguageHeaderValue(value: []const u8) bool {
    // Language headers: only 0x30-0x39, 0x41-0x5A, 0x61-0x7A, 0x20, 0x2A, 0x2C, 0x2D, 0x2E, 0x3B, 0x3D
    if (value.len > 128) return false;
    for (value) |c| {
        const valid = (c >= '0' and c <= '9') or
            (c >= 'A' and c <= 'Z') or
            (c >= 'a' and c <= 'z') or
            c == ' ' or c == '*' or c == ',' or c == '-' or c == '.' or c == ';' or c == '=';
        if (!valid) return false;
    }
    return true;
}

fn isSafeContentType(value: []const u8) bool {
    // Get MIME type (before ;)
    const semi = std.mem.indexOf(u8, value, ";");
    const mime = std.mem.trim(u8, if (semi) |pos| value[0..pos] else value, " \t");

    // Must be one of the safelisted types
    if (eqlIgnoreCase(mime, "application/x-www-form-urlencoded") or
        eqlIgnoreCase(mime, "multipart/form-data") or
        eqlIgnoreCase(mime, "text/plain"))
    {
        return isSafeHeaderValue(value);
    }
    return false;
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

fn startsWithIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (haystack.len < needle.len) return false;
    return eqlIgnoreCase(haystack[0..needle.len], needle);
}

// =============================================================================
// Tests
// =============================================================================

/// Mock header list for testing.
const MockHeaders = struct {
    headers: std.StringHashMap([]const u8),

    fn init(allocator: Allocator) MockHeaders {
        return .{ .headers = std.StringHashMap([]const u8).init(allocator) };
    }

    fn deinit(self: *MockHeaders) void {
        self.headers.deinit();
    }

    fn put(self: *MockHeaders, name: []const u8, value: []const u8) !void {
        try self.headers.put(name, value);
    }

    fn get(self: *const MockHeaders, name: []const u8) ?[]const u8 {
        return self.headers.get(name);
    }
};

test "corsCheck success with wildcard" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();
    try headers.put("Access-Control-Allow-Origin", "*");

    // Wildcard without credentials mode = include
    try std.testing.expectEqual(CorsCheckResult.success, corsCheck("https://example.com", .omit, headers));
    try std.testing.expectEqual(CorsCheckResult.success, corsCheck("https://example.com", .same_origin, headers));
}

test "corsCheck failure with wildcard and include credentials" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();
    try headers.put("Access-Control-Allow-Origin", "*");

    // Wildcard with credentials mode = include fails
    try std.testing.expectEqual(CorsCheckResult.failure, corsCheck("https://example.com", .include, headers));
}

test "corsCheck success with exact origin match" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();
    try headers.put("Access-Control-Allow-Origin", "https://example.com");

    try std.testing.expectEqual(CorsCheckResult.success, corsCheck("https://example.com", .omit, headers));
}

test "corsCheck failure with origin mismatch" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();
    try headers.put("Access-Control-Allow-Origin", "https://other.com");

    try std.testing.expectEqual(CorsCheckResult.failure, corsCheck("https://example.com", .omit, headers));
}

test "corsCheck success with credentials" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();
    try headers.put("Access-Control-Allow-Origin", "https://example.com");
    try headers.put("Access-Control-Allow-Credentials", "true");

    try std.testing.expectEqual(CorsCheckResult.success, corsCheck("https://example.com", .include, headers));
}

test "corsCheck failure without credentials header when needed" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();
    try headers.put("Access-Control-Allow-Origin", "https://example.com");

    // Credentials mode = include but no Allow-Credentials header
    try std.testing.expectEqual(CorsCheckResult.failure, corsCheck("https://example.com", .include, headers));
}

test "corsCheck failure with no Allow-Origin header" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();

    try std.testing.expectEqual(CorsCheckResult.failure, corsCheck("https://example.com", .omit, headers));
}

test "taoCheck success with wildcard" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();
    try headers.put("Timing-Allow-Origin", "*");

    try std.testing.expectEqual(TaoCheckResult.success, taoCheck("https://example.com", .omit, false, headers));
}

test "taoCheck failure with timing_allow_failed flag" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();
    try headers.put("Timing-Allow-Origin", "*");

    try std.testing.expectEqual(TaoCheckResult.failure, taoCheck("https://example.com", .omit, true, headers));
}

test "taoCheck success with origin match" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();
    try headers.put("Timing-Allow-Origin", "https://example.com, https://other.com");

    try std.testing.expectEqual(TaoCheckResult.success, taoCheck("https://example.com", .omit, false, headers));
}

test "taoCheck failure with no match" {
    const allocator = std.testing.allocator;

    var headers = MockHeaders.init(allocator);
    defer headers.deinit();
    try headers.put("Timing-Allow-Origin", "https://other.com");

    try std.testing.expectEqual(TaoCheckResult.failure, taoCheck("https://example.com", .omit, false, headers));
}

test "isCorseSafelistedMethod" {
    try std.testing.expect(isCorseSafelistedMethod("GET"));
    try std.testing.expect(isCorseSafelistedMethod("get"));
    try std.testing.expect(isCorseSafelistedMethod("HEAD"));
    try std.testing.expect(isCorseSafelistedMethod("POST"));
    try std.testing.expect(!isCorseSafelistedMethod("PUT"));
    try std.testing.expect(!isCorseSafelistedMethod("DELETE"));
}

test "isForbiddenHeaderName" {
    try std.testing.expect(isForbiddenHeaderName("Cookie"));
    try std.testing.expect(isForbiddenHeaderName("cookie"));
    try std.testing.expect(isForbiddenHeaderName("Host"));
    try std.testing.expect(isForbiddenHeaderName("Proxy-Authorization"));
    try std.testing.expect(isForbiddenHeaderName("Sec-Fetch-Mode"));
    try std.testing.expect(!isForbiddenHeaderName("X-Custom"));
    try std.testing.expect(!isForbiddenHeaderName("Content-Type"));
}

test "isForbiddenMethod" {
    try std.testing.expect(isForbiddenMethod("CONNECT"));
    try std.testing.expect(isForbiddenMethod("TRACE"));
    try std.testing.expect(isForbiddenMethod("TRACK"));
    try std.testing.expect(!isForbiddenMethod("GET"));
    try std.testing.expect(!isForbiddenMethod("POST"));
}

test "isCorseSafelistedRequestHeader" {
    try std.testing.expect(isCorseSafelistedRequestHeader("Accept", "text/html"));
    try std.testing.expect(isCorseSafelistedRequestHeader("Accept-Language", "en-US"));
    try std.testing.expect(isCorseSafelistedRequestHeader("Content-Type", "text/plain"));
    try std.testing.expect(isCorseSafelistedRequestHeader("Content-Type", "application/x-www-form-urlencoded"));
    try std.testing.expect(!isCorseSafelistedRequestHeader("Content-Type", "application/json"));
    try std.testing.expect(!isCorseSafelistedRequestHeader("Authorization", "Bearer token"));
}
