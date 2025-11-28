//! SameSite Determination per RFC 6265bis
//!
//! Spec: https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
//!
//! This module implements same-site status determination for cookies.

const std = @import("std");
const SameSite = @import("cookie.zig").SameSite;

/// SameSite request status.
pub const SameSiteStatus = enum {
    /// Request is same-site with the cookie's origin
    same_site,

    /// Request is cross-site
    cross_site,
};

/// Request type for SameSite evaluation.
pub const RequestType = enum {
    /// Top-level navigation (user clicking a link)
    top_level_navigation,

    /// Top-level navigation but unsafe method (POST form)
    top_level_unsafe,

    /// Subresource request (fetch, XHR, script, etc.)
    subresource,
};

/// Determine same-site status for a request.
///
/// Algorithm (§ 5.2):
/// Two origins are "same-site" if their registrable domains are equal.
///
/// Parameters:
/// - request_site: The site making the request (registrable domain)
/// - target_site: The target site (registrable domain)
pub fn determineSameSiteStatus(request_site: []const u8, target_site: []const u8) SameSiteStatus {
    // Same-site if registrable domains match
    if (eqlIgnoreCase(request_site, target_site)) {
        return .same_site;
    }
    return .cross_site;
}

/// Check if a cookie should be included based on SameSite attribute.
///
/// Algorithm (§ 5.4.7):
/// 1. If SameSite is "Strict", only include for same-site requests
/// 2. If SameSite is "Lax", include for same-site and top-level GET
/// 3. If SameSite is "None", include for all requests (with Secure)
/// 4. Default (no attribute): same as "Lax"
pub fn shouldIncludeCookie(
    same_site_attr: SameSite,
    status: SameSiteStatus,
    request_type: RequestType,
    is_secure: bool,
) bool {
    return switch (same_site_attr) {
        .strict => status == .same_site,

        .lax => status == .same_site or request_type == .top_level_navigation,

        .none => {
            // SameSite=None requires Secure attribute
            if (!is_secure) return false;
            return true;
        },

        .default => {
            // Default behavior: same as Lax (per spec update)
            return status == .same_site or request_type == .top_level_navigation;
        },
    };
}

/// Get the registrable domain from a host.
///
/// Simplified implementation that returns domain after first dot,
/// or the whole domain if no dots.
///
/// TODO(psl-spec): Use proper Public Suffix List for accurate results.
pub fn getRegistrableDomain(host: []const u8) []const u8 {
    // Handle IP addresses - they don't have registrable domains
    if (isIpAddress(host)) {
        return host;
    }

    // Find second-to-last dot
    var last_dot: ?usize = null;
    var second_last_dot: ?usize = null;

    for (host, 0..) |c, i| {
        if (c == '.') {
            second_last_dot = last_dot;
            last_dot = i;
        }
    }

    if (second_last_dot) |pos| {
        return host[pos + 1 ..];
    }

    return host;
}

/// Check if a string looks like an IP address.
fn isIpAddress(host: []const u8) bool {
    if (host.len == 0) return false;

    // IPv6 check
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

test "determineSameSiteStatus same site" {
    try std.testing.expectEqual(SameSiteStatus.same_site, determineSameSiteStatus("example.com", "example.com"));
    try std.testing.expectEqual(SameSiteStatus.same_site, determineSameSiteStatus("Example.Com", "example.com"));
}

test "determineSameSiteStatus cross site" {
    try std.testing.expectEqual(SameSiteStatus.cross_site, determineSameSiteStatus("example.com", "other.com"));
    try std.testing.expectEqual(SameSiteStatus.cross_site, determineSameSiteStatus("site-a.com", "site-b.com"));
}

test "shouldIncludeCookie strict" {
    // Strict only includes on same-site
    try std.testing.expect(shouldIncludeCookie(.strict, .same_site, .subresource, true));
    try std.testing.expect(!shouldIncludeCookie(.strict, .cross_site, .subresource, true));
    try std.testing.expect(!shouldIncludeCookie(.strict, .cross_site, .top_level_navigation, true));
}

test "shouldIncludeCookie lax" {
    // Lax includes on same-site and top-level cross-site navigation
    try std.testing.expect(shouldIncludeCookie(.lax, .same_site, .subresource, true));
    try std.testing.expect(shouldIncludeCookie(.lax, .cross_site, .top_level_navigation, true));
    try std.testing.expect(!shouldIncludeCookie(.lax, .cross_site, .subresource, true));
}

test "shouldIncludeCookie none requires secure" {
    // None includes all requests but requires Secure
    try std.testing.expect(shouldIncludeCookie(.none, .cross_site, .subresource, true));
    try std.testing.expect(!shouldIncludeCookie(.none, .cross_site, .subresource, false));
}

test "shouldIncludeCookie default is lax" {
    // Default behaves like Lax
    try std.testing.expect(shouldIncludeCookie(.default, .same_site, .subresource, true));
    try std.testing.expect(shouldIncludeCookie(.default, .cross_site, .top_level_navigation, true));
    try std.testing.expect(!shouldIncludeCookie(.default, .cross_site, .subresource, true));
}

test "getRegistrableDomain simple" {
    try std.testing.expectEqualStrings("example.com", getRegistrableDomain("www.example.com"));
    try std.testing.expectEqualStrings("example.com", getRegistrableDomain("example.com"));
    try std.testing.expectEqualStrings("localhost", getRegistrableDomain("localhost"));
}

test "getRegistrableDomain multiple subdomains" {
    try std.testing.expectEqualStrings("example.com", getRegistrableDomain("a.b.c.example.com"));
}

test "getRegistrableDomain IP address returns itself" {
    try std.testing.expectEqualStrings("192.168.1.1", getRegistrableDomain("192.168.1.1"));
}
