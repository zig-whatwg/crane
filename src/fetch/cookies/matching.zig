//! Cookie Matching Algorithms per RFC 6265bis
//!
//! Spec: https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
//!
//! This module implements domain and path matching for cookies.

const std = @import("std");
const Cookie = @import("cookie.zig").Cookie;

/// Check if cookie domain matches request host.
///
/// Algorithm (§ 5.1.3):
/// 1. If host-only flag set, domain must exactly match host
/// 2. Otherwise, host must domain-match cookie domain
pub fn domainMatches(cookie: Cookie, host: []const u8) bool {
    if (cookie.host_only) {
        // Host-only: exact match required
        return eqlIgnoreCase(cookie.domain orelse return eqlIgnoreCase(host, host), host);
    }

    // Domain cookie: use domain-match algorithm
    const domain = cookie.domain orelse return false;
    return domainMatch(host, domain);
}

/// Domain-match algorithm (§ 5.1.3).
///
/// Host domain-matches cookie domain if:
/// 1. They are identical (case-insensitive), OR
/// 2. All of the following are true:
///    a. Cookie domain is a suffix of host
///    b. The last character of host before the suffix is '.'
///    c. Host is not an IP address
pub fn domainMatch(host: []const u8, domain: []const u8) bool {
    // Case 1: Identical (case-insensitive)
    if (eqlIgnoreCase(host, domain)) {
        return true;
    }

    // Case 2: Domain is suffix of host
    if (host.len <= domain.len) {
        return false;
    }

    // Check if domain is a suffix
    const suffix_start = host.len - domain.len;
    const suffix = host[suffix_start..];

    if (!eqlIgnoreCase(suffix, domain)) {
        return false;
    }

    // Check for dot separator
    if (host[suffix_start - 1] != '.') {
        return false;
    }

    // Check if host is an IP address (simplified check)
    if (isIpAddress(host)) {
        return false;
    }

    return true;
}

/// Check if cookie path matches request path.
///
/// Algorithm (§ 5.1.4):
/// Cookie path-matches request path if:
/// 1. Cookie path equals request path, OR
/// 2. Cookie path is a prefix of request path AND
///    (cookie path ends with '/' OR request path char after prefix is '/')
pub fn pathMatches(cookie_path: []const u8, request_path: []const u8) bool {
    // Empty request path is treated as "/"
    const req_path = if (request_path.len == 0) "/" else request_path;
    const cookie_p = if (cookie_path.len == 0) "/" else cookie_path;

    // Case 1: Identical paths
    if (std.mem.eql(u8, cookie_p, req_path)) {
        return true;
    }

    // Case 2: Cookie path is prefix
    if (!std.mem.startsWith(u8, req_path, cookie_p)) {
        return false;
    }

    // Cookie path is a prefix - check separator conditions
    // If cookie path ends with '/', it's always a match
    if (cookie_p[cookie_p.len - 1] == '/') {
        return true;
    }

    // Otherwise, the next char in request path must be '/'
    if (req_path.len > cookie_p.len and req_path[cookie_p.len] == '/') {
        return true;
    }

    return false;
}

/// Get the default path from a request URI.
///
/// Algorithm (§ 5.1.4):
/// 1. If URI path is empty or doesn't start with '/', return "/"
/// 2. If path contains only one '/', return "/"
/// 3. Return path up to (but not including) the rightmost '/'
pub fn defaultPath(uri_path: []const u8) []const u8 {
    // Step 1: Empty or doesn't start with /
    if (uri_path.len == 0 or uri_path[0] != '/') {
        return "/";
    }

    // Step 2-3: Find rightmost /
    var last_slash: ?usize = null;
    for (uri_path, 0..) |c, i| {
        if (c == '/') {
            last_slash = i;
        }
    }

    // If only one slash at position 0, return "/"
    if (last_slash == null or last_slash.? == 0) {
        return "/";
    }

    // Return up to (not including) the last slash
    return uri_path[0..last_slash.?];
}

/// Check if a string looks like an IP address.
///
/// Simplified check: IPv4 (digits and dots) or IPv6 (contains ':').
fn isIpAddress(host: []const u8) bool {
    if (host.len == 0) return false;

    // IPv6 check (contains colon or starts with '[')
    if (std.mem.indexOf(u8, host, ":") != null or host[0] == '[') {
        return true;
    }

    // IPv4 check: all chars are digits or dots
    for (host) |c| {
        if (c != '.' and (c < '0' or c > '9')) {
            return false;
        }
    }

    return true;
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

test "domainMatch exact match" {
    try std.testing.expect(domainMatch("example.com", "example.com"));
    try std.testing.expect(domainMatch("Example.Com", "example.com"));
    try std.testing.expect(domainMatch("EXAMPLE.COM", "example.com"));
}

test "domainMatch subdomain" {
    try std.testing.expect(domainMatch("www.example.com", "example.com"));
    try std.testing.expect(domainMatch("api.example.com", "example.com"));
    try std.testing.expect(domainMatch("sub.www.example.com", "example.com"));
}

test "domainMatch no match" {
    try std.testing.expect(!domainMatch("example.com", "other.com"));
    try std.testing.expect(!domainMatch("notexample.com", "example.com"));
    try std.testing.expect(!domainMatch("com", "example.com"));
}

test "domainMatch IP addresses don't match domains" {
    try std.testing.expect(!domainMatch("192.168.1.1", "1.1"));
    try std.testing.expect(domainMatch("192.168.1.1", "192.168.1.1")); // Exact match OK
}

test "pathMatches exact match" {
    try std.testing.expect(pathMatches("/", "/"));
    try std.testing.expect(pathMatches("/path", "/path"));
    try std.testing.expect(pathMatches("/path/to/resource", "/path/to/resource"));
}

test "pathMatches prefix" {
    try std.testing.expect(pathMatches("/", "/anything"));
    try std.testing.expect(pathMatches("/path", "/path/subpath"));
    try std.testing.expect(pathMatches("/path/", "/path/subpath"));
    try std.testing.expect(pathMatches("/api", "/api/v1"));
}

test "pathMatches no match" {
    try std.testing.expect(!pathMatches("/path", "/other"));
    try std.testing.expect(!pathMatches("/api", "/apiv2")); // Not a path boundary
    try std.testing.expect(!pathMatches("/path/subpath", "/path"));
}

test "pathMatches empty request path" {
    try std.testing.expect(pathMatches("/", ""));
}

test "defaultPath" {
    try std.testing.expectEqualStrings("/", defaultPath(""));
    try std.testing.expectEqualStrings("/", defaultPath("relative"));
    try std.testing.expectEqualStrings("/", defaultPath("/"));
    try std.testing.expectEqualStrings("/", defaultPath("/file.html"));
    try std.testing.expectEqualStrings("/path", defaultPath("/path/file.html"));
    try std.testing.expectEqualStrings("/path/to", defaultPath("/path/to/resource"));
}

test "isIpAddress" {
    try std.testing.expect(isIpAddress("192.168.1.1"));
    try std.testing.expect(isIpAddress("127.0.0.1"));
    try std.testing.expect(isIpAddress("::1"));
    try std.testing.expect(isIpAddress("[::1]"));
    try std.testing.expect(!isIpAddress("example.com"));
    try std.testing.expect(!isIpAddress("localhost"));
}
