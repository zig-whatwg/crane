//! Set-Cookie Header Parsing per RFC 6265bis
//!
//! Spec: https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
//!
//! This module parses Set-Cookie headers and builds Cookie headers.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Cookie = @import("cookie.zig").Cookie;
const SameSite = @import("cookie.zig").SameSite;
const matching = @import("matching.zig");

/// Parse errors
pub const ParseError = error{
    InvalidCookie,
    OutOfMemory,
};

/// Parse a Set-Cookie header value into a Cookie.
///
/// Format: name=value [; attribute]*
/// Attributes: Expires, Max-Age, Domain, Path, Secure, HttpOnly, SameSite, Partitioned
///
/// Parameters:
/// - allocator: For allocating cookie strings
/// - value: The Set-Cookie header value
/// - request_host: The host from the request URL
/// - request_path: The path from the request URL
///
/// Returns null if the cookie should be rejected (invalid name, etc.)
pub fn parseSetCookie(
    allocator: Allocator,
    value: []const u8,
    request_host: []const u8,
    request_path: []const u8,
) ParseError!?Cookie {
    // Split on first '='
    const eq_pos = std.mem.indexOf(u8, value, "=") orelse return null;
    if (eq_pos == 0) return null; // Empty name

    const name = std.mem.trim(u8, value[0..eq_pos], " \t");
    if (name.len == 0) return null;

    // Find end of value (before first ';')
    const after_eq = value[eq_pos + 1 ..];
    const semi_pos = std.mem.indexOf(u8, after_eq, ";");
    const cookie_value = std.mem.trim(u8, if (semi_pos) |pos| after_eq[0..pos] else after_eq, " \t");

    // Create cookie with defaults
    var cookie = try Cookie.init(allocator, name, cookie_value, matching.defaultPath(request_path));
    errdefer cookie.deinit();

    // Parse attributes
    if (semi_pos) |pos| {
        const attrs_str = after_eq[pos + 1 ..];
        try parseAttributes(allocator, &cookie, attrs_str, request_host);
    }

    // Apply default domain (host-only)
    if (cookie.domain == null) {
        cookie.domain = try allocator.dupe(u8, request_host);
        cookie.host_only = true;
    }

    return cookie;
}

/// Parse cookie attributes from the string after the value.
fn parseAttributes(
    allocator: Allocator,
    cookie: *Cookie,
    attrs_str: []const u8,
    request_host: []const u8,
) !void {
    var iter = std.mem.splitScalar(u8, attrs_str, ';');
    while (iter.next()) |attr| {
        const trimmed = std.mem.trim(u8, attr, " \t");
        if (trimmed.len == 0) continue;

        // Check for '=' to separate name from value
        if (std.mem.indexOf(u8, trimmed, "=")) |eq| {
            const attr_name = std.mem.trim(u8, trimmed[0..eq], " \t");
            const attr_value = std.mem.trim(u8, trimmed[eq + 1 ..], " \t");
            try parseAttributeWithValue(allocator, cookie, attr_name, attr_value, request_host);
        } else {
            // Flag attribute (no value)
            try parseAttributeFlag(cookie, trimmed);
        }
    }
}

/// Parse an attribute with a value.
fn parseAttributeWithValue(
    allocator: Allocator,
    cookie: *Cookie,
    name: []const u8,
    value: []const u8,
    request_host: []const u8,
) !void {
    if (eqlIgnoreCase(name, "Domain")) {
        // Remove leading dot if present (legacy)
        var domain = value;
        if (domain.len > 0 and domain[0] == '.') {
            domain = domain[1..];
        }

        // Validate domain matches request host
        if (matching.domainMatch(request_host, domain) or eqlIgnoreCase(request_host, domain)) {
            try cookie.setDomain(domain);
        }
        // If domain doesn't match, we silently ignore (per spec)
    } else if (eqlIgnoreCase(name, "Path")) {
        if (value.len > 0 and value[0] == '/') {
            allocator.free(cookie.path);
            cookie.path = try allocator.dupe(u8, value);
        }
    } else if (eqlIgnoreCase(name, "Expires")) {
        if (parseHttpDate(value)) |timestamp| {
            // Only set if Max-Age hasn't been set (Max-Age takes precedence)
            if (cookie.expiry_time == null) {
                cookie.expiry_time = timestamp;
            }
        }
    } else if (eqlIgnoreCase(name, "Max-Age")) {
        if (std.fmt.parseInt(i64, value, 10)) |seconds| {
            if (seconds <= 0) {
                // Max-Age=0 or negative means delete immediately
                cookie.expiry_time = 0;
            } else {
                cookie.expiry_time = std.time.timestamp() + seconds;
            }
        } else |_| {}
    } else if (eqlIgnoreCase(name, "SameSite")) {
        cookie.same_site = SameSite.parse(value);
    }
    // Unknown attributes are ignored
}

/// Parse a flag attribute (no value).
fn parseAttributeFlag(cookie: *Cookie, name: []const u8) !void {
    if (eqlIgnoreCase(name, "Secure")) {
        cookie.secure_only = true;
    } else if (eqlIgnoreCase(name, "HttpOnly")) {
        cookie.http_only = true;
    } else if (eqlIgnoreCase(name, "Partitioned")) {
        cookie.partitioned = true;
    }
    // Unknown flags are ignored
}

/// Build Cookie header value from a list of cookies.
///
/// Format: name1=value1; name2=value2
///
/// Cookies should be pre-sorted by path length (longest first) and creation time.
pub fn buildCookieHeader(allocator: Allocator, cookies: []const Cookie) ![]const u8 {
    if (cookies.len == 0) return try allocator.dupe(u8, "");

    var size: usize = 0;
    for (cookies, 0..) |cookie, i| {
        size += cookie.name.len + 1 + cookie.value.len; // name=value
        if (i < cookies.len - 1) size += 2; // "; "
    }

    var result = try allocator.alloc(u8, size);
    var pos: usize = 0;

    for (cookies, 0..) |cookie, i| {
        @memcpy(result[pos..][0..cookie.name.len], cookie.name);
        pos += cookie.name.len;
        result[pos] = '=';
        pos += 1;
        @memcpy(result[pos..][0..cookie.value.len], cookie.value);
        pos += cookie.value.len;
        if (i < cookies.len - 1) {
            result[pos] = ';';
            result[pos + 1] = ' ';
            pos += 2;
        }
    }

    return result;
}

/// Parse HTTP date format (simplified).
///
/// Supports: "Sun, 06 Nov 1994 08:49:37 GMT" (RFC 1123)
///
/// TODO(http-date): Full HTTP date parsing with RFC 850 and asctime formats.
fn parseHttpDate(date: []const u8) ?i64 {
    // Very simplified parsing - just extract the components
    // Format: "Day, DD Mon YYYY HH:MM:SS GMT"

    var iter = std.mem.tokenizeAny(u8, date, " ,:-");

    // Skip day name
    _ = iter.next() orelse return null;

    // Day
    const day_str = iter.next() orelse return null;
    const day = std.fmt.parseInt(u8, day_str, 10) catch return null;

    // Month
    const month_str = iter.next() orelse return null;
    const month = monthToNumber(month_str) orelse return null;

    // Year
    const year_str = iter.next() orelse return null;
    var year = std.fmt.parseInt(i32, year_str, 10) catch return null;

    // Handle 2-digit years
    if (year < 70) {
        year += 2000;
    } else if (year < 100) {
        year += 1900;
    }

    // Hour
    const hour_str = iter.next() orelse return null;
    const hour = std.fmt.parseInt(u8, hour_str, 10) catch return null;

    // Minute
    const min_str = iter.next() orelse return null;
    const min = std.fmt.parseInt(u8, min_str, 10) catch return null;

    // Second
    const sec_str = iter.next() orelse return null;
    const sec = std.fmt.parseInt(u8, sec_str, 10) catch return null;

    // Convert to timestamp (simplified - doesn't handle all edge cases)
    return dateToTimestamp(year, month, day, hour, min, sec);
}

fn monthToNumber(month: []const u8) ?u8 {
    const months = [_][]const u8{
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    };

    for (months, 1..) |m, i| {
        if (eqlIgnoreCase(month, m)) {
            return @intCast(i);
        }
    }
    return null;
}

fn dateToTimestamp(year: i32, month: u8, day: u8, hour: u8, min: u8, sec: u8) i64 {
    // Simplified conversion - use days since epoch
    // This is approximate but sufficient for cookie expiry comparisons
    const days_since_epoch = daysSinceEpoch(year, month, day);
    const seconds_in_day: i64 = 86400;
    return days_since_epoch * seconds_in_day + @as(i64, hour) * 3600 + @as(i64, min) * 60 + @as(i64, sec);
}

fn daysSinceEpoch(year: i32, month: u8, day: u8) i64 {
    // Count days from 1970-01-01
    var total: i64 = 0;

    // Years
    var y: i32 = 1970;
    while (y < year) : (y += 1) {
        total += if (isLeapYear(y)) 366 else 365;
    }

    // Months
    const days_in_month = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    var m: u8 = 1;
    while (m < month) : (m += 1) {
        total += days_in_month[m - 1];
        if (m == 2 and isLeapYear(year)) {
            total += 1;
        }
    }

    // Days
    total += day - 1;

    return total;
}

fn isLeapYear(year: i32) bool {
    return (@mod(year, 4) == 0 and @mod(year, 100) != 0) or @mod(year, 400) == 0;
}

/// Case-insensitive string comparison for ASCII.
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

test "parseSetCookie simple cookie" {
    const allocator = std.testing.allocator;

    var cookie = (try parseSetCookie(allocator, "session=abc123", "example.com", "/")).?;
    defer cookie.deinit();

    try std.testing.expectEqualStrings("session", cookie.name);
    try std.testing.expectEqualStrings("abc123", cookie.value);
    try std.testing.expect(cookie.host_only);
}

test "parseSetCookie with attributes" {
    const allocator = std.testing.allocator;

    var cookie = (try parseSetCookie(
        allocator,
        "token=xyz; Path=/api; Secure; HttpOnly; SameSite=Strict",
        "example.com",
        "/",
    )).?;
    defer cookie.deinit();

    try std.testing.expectEqualStrings("token", cookie.name);
    try std.testing.expectEqualStrings("xyz", cookie.value);
    try std.testing.expectEqualStrings("/api", cookie.path);
    try std.testing.expect(cookie.secure_only);
    try std.testing.expect(cookie.http_only);
    try std.testing.expectEqual(SameSite.strict, cookie.same_site);
}

test "parseSetCookie with domain" {
    const allocator = std.testing.allocator;

    var cookie = (try parseSetCookie(
        allocator,
        "test=value; Domain=example.com",
        "sub.example.com",
        "/",
    )).?;
    defer cookie.deinit();

    try std.testing.expectEqualStrings("example.com", cookie.domain.?);
    try std.testing.expect(!cookie.host_only);
}

test "parseSetCookie with leading dot domain" {
    const allocator = std.testing.allocator;

    var cookie = (try parseSetCookie(
        allocator,
        "test=value; Domain=.example.com",
        "sub.example.com",
        "/",
    )).?;
    defer cookie.deinit();

    try std.testing.expectEqualStrings("example.com", cookie.domain.?);
}

test "parseSetCookie with Max-Age" {
    const allocator = std.testing.allocator;

    var cookie = (try parseSetCookie(
        allocator,
        "test=value; Max-Age=3600",
        "example.com",
        "/",
    )).?;
    defer cookie.deinit();

    try std.testing.expect(cookie.expiry_time != null);
    const now = std.time.timestamp();
    // Should be approximately 1 hour from now
    try std.testing.expect(cookie.expiry_time.? > now);
    try std.testing.expect(cookie.expiry_time.? <= now + 3601);
}

test "parseSetCookie with Max-Age=0" {
    const allocator = std.testing.allocator;

    var cookie = (try parseSetCookie(
        allocator,
        "test=value; Max-Age=0",
        "example.com",
        "/",
    )).?;
    defer cookie.deinit();

    try std.testing.expectEqual(@as(?i64, 0), cookie.expiry_time);
    try std.testing.expect(cookie.isExpired());
}

test "parseSetCookie empty name returns null" {
    const allocator = std.testing.allocator;

    const result = try parseSetCookie(allocator, "=value", "example.com", "/");
    try std.testing.expect(result == null);
}

test "parseSetCookie no equals returns null" {
    const allocator = std.testing.allocator;

    const result = try parseSetCookie(allocator, "nocookie", "example.com", "/");
    try std.testing.expect(result == null);
}

test "parseSetCookie default path from request" {
    const allocator = std.testing.allocator;

    var cookie = (try parseSetCookie(allocator, "test=value", "example.com", "/api/v1/users")).?;
    defer cookie.deinit();

    try std.testing.expectEqualStrings("/api/v1", cookie.path);
}

test "buildCookieHeader single cookie" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "session", "abc123", "/");
    defer cookie.deinit();

    const cookies = [_]Cookie{cookie};
    const header = try buildCookieHeader(allocator, &cookies);
    defer allocator.free(header);

    try std.testing.expectEqualStrings("session=abc123", header);
}

test "buildCookieHeader multiple cookies" {
    const allocator = std.testing.allocator;

    var cookie1 = try Cookie.init(allocator, "a", "1", "/");
    defer cookie1.deinit();

    var cookie2 = try Cookie.init(allocator, "b", "2", "/");
    defer cookie2.deinit();

    const cookies = [_]Cookie{ cookie1, cookie2 };
    const header = try buildCookieHeader(allocator, &cookies);
    defer allocator.free(header);

    try std.testing.expectEqualStrings("a=1; b=2", header);
}

test "buildCookieHeader empty list" {
    const allocator = std.testing.allocator;

    const cookies = [_]Cookie{};
    const header = try buildCookieHeader(allocator, &cookies);
    defer allocator.free(header);

    try std.testing.expectEqualStrings("", header);
}

test "parseHttpDate RFC 1123 format" {
    // Sun, 06 Nov 1994 08:49:37 GMT
    const timestamp = parseHttpDate("Sun, 06 Nov 1994 08:49:37 GMT");
    try std.testing.expect(timestamp != null);

    // The timestamp should be a specific value
    // Nov 6, 1994 08:49:37 GMT = 784111777
    try std.testing.expectEqual(@as(i64, 784111777), timestamp.?);
}

test "monthToNumber" {
    try std.testing.expectEqual(@as(?u8, 1), monthToNumber("Jan"));
    try std.testing.expectEqual(@as(?u8, 6), monthToNumber("Jun"));
    try std.testing.expectEqual(@as(?u8, 12), monthToNumber("Dec"));
    try std.testing.expect(monthToNumber("Invalid") == null);
}
