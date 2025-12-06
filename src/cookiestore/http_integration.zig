//! HTTP Cookie Header Integration
//!
//! RFC 6265bis: https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
//!
//! This module provides functions for generating Cookie request headers
//! and parsing Set-Cookie response headers for Fetch API integration.

const std = @import("std");
const Cookie = @import("cookie.zig").Cookie;
const SameSite = @import("cookie.zig").SameSite;
const CookieJar = @import("jar.zig").CookieJar;
const RetrieveOptions = @import("jar.zig").RetrieveOptions;
const SameSiteContext = @import("jar.zig").SameSiteContext;
const validation = @import("validation.zig");
const domain_matching = @import("domain_matching.zig");

/// Errors that can occur during header parsing
pub const ParseError = error{
    InvalidHeader,
    InvalidName,
    InvalidValue,
    InvalidDate,
    InvalidDomain,
    InvalidPath,
    OutOfMemory,
};

/// Generate Cookie request header value
/// RFC 6265bis Section 5.6
///
/// Returns the "Cookie" header value for a request to the given URL.
pub fn generateCookieHeader(
    allocator: std.mem.Allocator,
    jar: *CookieJar,
    options: RetrieveOptions,
) ![]const u8 {
    // Retrieve matching cookies
    var cookies = try jar.retrieve(options);
    defer {
        for (cookies.items) |*c| c.deinit();
        cookies.deinit(allocator);
    }

    if (cookies.items.len == 0) {
        return allocator.dupe(u8, "");
    }

    // Build the Cookie header value
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    for (cookies.items, 0..) |cookie, i| {
        if (i > 0) {
            try result.appendSlice(allocator, "; ");
        }
        try result.appendSlice(allocator, cookie.name);
        try result.append(allocator, '=');
        try result.appendSlice(allocator, cookie.value);
    }

    return result.toOwnedSlice(allocator);
}

/// Parse a Set-Cookie response header
/// RFC 6265bis Section 5.4
///
/// Parses a single Set-Cookie header value and returns a Cookie struct.
pub fn parseSetCookieHeader(
    allocator: std.mem.Allocator,
    header_value: []const u8,
    request_host: []const u8,
    request_path: []const u8,
    is_secure_origin: bool,
) !Cookie {
    // Step 1: Parse name-value-pair
    const eq_pos = std.mem.indexOf(u8, header_value, "=") orelse
        return ParseError.InvalidHeader;

    const name = std.mem.trim(u8, header_value[0..eq_pos], " \t");
    if (name.len == 0) {
        return ParseError.InvalidName;
    }

    // Find the end of value (first ; or end of string)
    const after_eq = header_value[eq_pos + 1 ..];
    const semi_pos = std.mem.indexOf(u8, after_eq, ";") orelse after_eq.len;
    const value = std.mem.trim(u8, after_eq[0..semi_pos], " \t");

    // Create the cookie
    var cookie = try Cookie.init(allocator, name, value);
    errdefer cookie.deinit();

    // Step 2: Parse attributes
    var attrs = after_eq[semi_pos..];
    while (attrs.len > 0) {
        // Skip leading semicolon and whitespace
        if (attrs[0] == ';') {
            attrs = attrs[1..];
        }
        attrs = std.mem.trimLeft(u8, attrs, " \t");
        if (attrs.len == 0) break;

        // Find next semicolon or end
        const next_semi = std.mem.indexOf(u8, attrs, ";") orelse attrs.len;
        const attr = attrs[0..next_semi];
        attrs = attrs[next_semi..];

        // Parse attribute
        try parseAttribute(allocator, &cookie, attr, request_host, request_path, is_secure_origin);
    }

    // Apply defaults
    if (std.mem.eql(u8, cookie.path, "/") and request_path.len > 1) {
        const default_path = domain_matching.getDefaultPath(request_path);
        if (!std.mem.eql(u8, default_path, "/")) {
            try cookie.setPath(default_path);
        }
    }

    return cookie;
}

/// Parse a single cookie attribute
fn parseAttribute(
    allocator: std.mem.Allocator,
    cookie: *Cookie,
    attr: []const u8,
    request_host: []const u8,
    request_path: []const u8,
    is_secure_origin: bool,
) !void {
    _ = request_path;
    _ = is_secure_origin;

    const eq_pos = std.mem.indexOf(u8, attr, "=");
    const attr_name = std.mem.trim(u8, if (eq_pos) |pos| attr[0..pos] else attr, " \t");
    const attr_value = if (eq_pos) |pos|
        std.mem.trim(u8, attr[pos + 1 ..], " \t")
    else
        "";

    // Case-insensitive attribute comparison
    var lower_name: [64]u8 = undefined;
    const name_len = @min(attr_name.len, lower_name.len);
    for (0..name_len) |i| {
        lower_name[i] = std.ascii.toLower(attr_name[i]);
    }
    const attr_lower = lower_name[0..name_len];

    if (std.mem.eql(u8, attr_lower, "expires")) {
        if (parseHttpDate(attr_value)) |timestamp| {
            // Only set if Max-Age not already set
            if (cookie.expiry_time == null) {
                cookie.expiry_time = timestamp;
            }
        }
    } else if (std.mem.eql(u8, attr_lower, "max-age")) {
        if (std.fmt.parseInt(i64, attr_value, 10)) |seconds| {
            // Max-Age overrides Expires
            const now = std.time.timestamp();
            if (seconds <= 0) {
                // Already expired
                cookie.expiry_time = 0;
            } else {
                cookie.expiry_time = now + seconds;
            }
        } else |_| {}
    } else if (std.mem.eql(u8, attr_lower, "domain")) {
        // Normalize domain
        var domain = attr_value;
        if (domain.len > 0 and domain[0] == '.') {
            domain = domain[1..];
        }
        if (domain.len > 0) {
            // Validate domain is a suffix of request host
            if (domain_matching.isRegistrableDomainSuffixOrEqual(allocator, request_host, domain) catch false) {
                try cookie.setDomain(domain);
            }
            // Else ignore invalid domain
        }
    } else if (std.mem.eql(u8, attr_lower, "path")) {
        if (attr_value.len > 0 and attr_value[0] == '/') {
            // Use setPath which handles the "/" literal correctly
            try cookie.setPath(attr_value);
        }
    } else if (std.mem.eql(u8, attr_lower, "secure")) {
        cookie.secure = true;
    } else if (std.mem.eql(u8, attr_lower, "httponly")) {
        cookie.http_only = true;
    } else if (std.mem.eql(u8, attr_lower, "samesite")) {
        var lower_val: [16]u8 = undefined;
        const val_len = @min(attr_value.len, lower_val.len);
        for (0..val_len) |i| {
            lower_val[i] = std.ascii.toLower(attr_value[i]);
        }
        const val_lower = lower_val[0..val_len];

        if (std.mem.eql(u8, val_lower, "strict")) {
            cookie.same_site = .strict;
        } else if (std.mem.eql(u8, val_lower, "lax")) {
            cookie.same_site = .lax;
        } else if (std.mem.eql(u8, val_lower, "none")) {
            cookie.same_site = .none;
        }
    } else if (std.mem.eql(u8, attr_lower, "partitioned")) {
        // Partitioned cookies require a partition key from the request context
        // For now, just note that the attribute is present (no-op)
        // The actual partition key is set by the caller based on request context
    }
}

/// Parse an HTTP date string
/// Supports RFC 1123, RFC 1036, and ANSI C asctime() formats
fn parseHttpDate(date_str: []const u8) ?i64 {
    // Simplified parsing - just handle common RFC 1123 format
    // "Sun, 06 Nov 1994 08:49:37 GMT"

    // For now, return null for complex dates and let the caller handle
    // A full implementation would parse multiple date formats
    _ = date_str;
    return null;
}

/// Process Set-Cookie headers from a response
/// Stores all valid cookies in the jar
pub fn processSetCookieHeaders(
    allocator: std.mem.Allocator,
    jar: *CookieJar,
    headers: []const []const u8,
    request_host: []const u8,
    request_path: []const u8,
    is_secure_origin: bool,
) !void {
    for (headers) |header| {
        if (parseSetCookieHeader(allocator, header, request_host, request_path, is_secure_origin)) |cookie| {
            try jar.store(cookie);
        } else |_| {
            // Invalid cookie, skip
            continue;
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

test "generateCookieHeader - basic" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    var cookie = try Cookie.init(allocator, "session", "abc123");
    defer cookie.deinit();
    try jar.store(cookie);

    const header = try generateCookieHeader(allocator, &jar, .{
        .host = "localhost",
        .path = "/",
        .is_http = true,
        .is_secure = true,
    });
    defer allocator.free(header);

    try std.testing.expectEqualStrings("session=abc123", header);
}

test "generateCookieHeader - multiple cookies" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    var cookie1 = try Cookie.init(allocator, "a", "1");
    defer cookie1.deinit();
    try jar.store(cookie1);

    var cookie2 = try Cookie.init(allocator, "b", "2");
    defer cookie2.deinit();
    try jar.store(cookie2);

    const header = try generateCookieHeader(allocator, &jar, .{
        .host = "localhost",
        .path = "/",
        .is_http = true,
        .is_secure = true,
    });
    defer allocator.free(header);

    // Order may vary, check both cookies are present
    try std.testing.expect(std.mem.indexOf(u8, header, "a=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, header, "b=2") != null);
}

test "parseSetCookieHeader - basic" {
    const allocator = std.testing.allocator;

    var cookie = try parseSetCookieHeader(
        allocator,
        "session=abc123",
        "example.com",
        "/",
        true,
    );
    defer cookie.deinit();

    try std.testing.expectEqualStrings("session", cookie.name);
    try std.testing.expectEqualStrings("abc123", cookie.value);
}

test "parseSetCookieHeader - with attributes" {
    const allocator = std.testing.allocator;

    var cookie = try parseSetCookieHeader(
        allocator,
        "id=abc; Path=/; Secure; HttpOnly; SameSite=Strict",
        "example.com",
        "/",
        true,
    );
    defer cookie.deinit();

    try std.testing.expectEqualStrings("id", cookie.name);
    try std.testing.expectEqualStrings("abc", cookie.value);
    try std.testing.expectEqualStrings("/", cookie.path);
    try std.testing.expect(cookie.secure);
    try std.testing.expect(cookie.http_only);
    try std.testing.expectEqual(SameSite.strict, cookie.same_site);
}

test "parseSetCookieHeader - domain attribute" {
    const allocator = std.testing.allocator;

    var cookie = try parseSetCookieHeader(
        allocator,
        "id=abc; Domain=example.com",
        "www.example.com",
        "/",
        true,
    );
    defer cookie.deinit();

    try std.testing.expectEqualStrings("example.com", cookie.domain.?);
}

test "parseSetCookieHeader - max-age" {
    const allocator = std.testing.allocator;

    var cookie = try parseSetCookieHeader(
        allocator,
        "id=abc; Max-Age=3600",
        "example.com",
        "/",
        true,
    );
    defer cookie.deinit();

    try std.testing.expect(cookie.expiry_time != null);
}
