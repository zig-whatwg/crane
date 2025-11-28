//! Origin Utilities for HTML/Fetch Integration
//!
//! TODO(html-spec): This extends src/url/origin.zig with HTML-specific
//! origin operations needed by Fetch.
//!
//! Provides:
//! - isSameOriginDomain() for document.domain handling
//! - isSameSite() for cookie SameSite checks
//! - getRegistrableDomain() for same-site determination

const std = @import("std");
const Allocator = std.mem.Allocator;
const environment = @import("environment.zig");
const Origin = @import("../url/origin.zig").Origin;

// =============================================================================
// Same Origin Domain
// =============================================================================

/// Check if two origins are same-origin-domain.
///
/// Spec: https://html.spec.whatwg.org/#same-origin-domain
///
/// Algorithm (considers document.domain):
/// 1. If A and B are same origin, return true
/// 2. If both tuple origins with non-null domain:
///    a. If scheme, domain match: return true
/// 3. Return false
///
/// TODO(html-spec): Full document.domain support requires tracking
/// the domain property on origins, which is deprecated but still used.
pub fn isSameOriginDomain(a: Origin, b: Origin) bool {
    // For now, same-origin-domain is equivalent to same-origin
    // since we don't track document.domain
    return environment.sameOrigin(a, b);
}

// =============================================================================
// Same Site
// =============================================================================

/// Check if origin A is same-site with origin B.
///
/// Spec: https://html.spec.whatwg.org/#same-site
///
/// Algorithm:
/// 1. If A and B are both opaque, return true if same
/// 2. If one is opaque, return false
/// 3. Let hostA = A's registrable domain (or host if none)
/// 4. Let hostB = B's registrable domain (or host if none)
/// 5. If hostA equals hostB and A's scheme equals B's scheme, return true
/// 6. Return false
pub fn isSameSite(a: Origin, b: Origin) bool {
    switch (a) {
        .opaque_origin => {
            // Opaque origins are never same-site
            return false;
        },
        .tuple => |ta| {
            switch (b) {
                .opaque_origin => return false,
                .tuple => |tb| {
                    // Check scheme first
                    if (!std.mem.eql(u8, ta.scheme, tb.scheme)) {
                        return false;
                    }

                    // Get host strings
                    const host_a = getHostString(ta.host);
                    const host_b = getHostString(tb.host);

                    if (host_a == null or host_b == null) {
                        return false;
                    }

                    // Get registrable domains
                    const reg_a = getRegistrableDomain(host_a.?) orelse host_a.?;
                    const reg_b = getRegistrableDomain(host_b.?) orelse host_b.?;

                    return std.mem.eql(u8, reg_a, reg_b);
                },
            }
        },
    }
}

/// Get host as string for same-site comparison.
fn getHostString(host: anytype) ?[]const u8 {
    switch (host) {
        .domain => |d| return d,
        .ipv4 => return null, // IP addresses don't have registrable domains
        .ipv6 => return null,
        .opaque_host => |o| return o,
        .empty => return null,
    }
}

// =============================================================================
// Registrable Domain
// =============================================================================

/// Get the registrable domain of a host.
///
/// The registrable domain is the public suffix + one label.
/// e.g., "www.example.com" -> "example.com"
///       "www.bbc.co.uk" -> "bbc.co.uk"
///
/// TODO(psl-spec): This is a simplified implementation.
/// Full implementation should use the Public Suffix List from
/// src/url/public_suffix.zig
pub fn getRegistrableDomain(host: []const u8) ?[]const u8 {
    // Simple implementation: assume TLD is last dot-separated segment
    // For proper implementation, use Public Suffix List

    // Handle IP addresses - they don't have registrable domains
    if (host.len == 0) return null;

    // Check for IPv4 (contains only digits and dots)
    var is_ip = true;
    for (host) |c| {
        if (c != '.' and (c < '0' or c > '9')) {
            is_ip = false;
            break;
        }
    }
    if (is_ip) return null;

    // Find the last two dots to get registrable domain
    var last_dot: ?usize = null;
    var second_last_dot: ?usize = null;

    for (host, 0..) |c, i| {
        if (c == '.') {
            second_last_dot = last_dot;
            last_dot = i;
        }
    }

    if (last_dot == null) {
        // No dots - single label domain, return as-is
        return host;
    }

    if (second_last_dot) |sld| {
        // Return from second-to-last dot + 1
        return host[sld + 1 ..];
    } else {
        // Only one dot - return entire host
        return host;
    }
}

/// Check if two URLs are schemelessly same-site.
///
/// Same as same-site but ignores scheme.
pub fn isSchemelesslySameSite(a: Origin, b: Origin) bool {
    switch (a) {
        .opaque_origin => return false,
        .tuple => |ta| {
            switch (b) {
                .opaque_origin => return false,
                .tuple => |tb| {
                    const host_a = getHostString(ta.host);
                    const host_b = getHostString(tb.host);

                    if (host_a == null or host_b == null) {
                        return false;
                    }

                    const reg_a = getRegistrableDomain(host_a.?) orelse host_a.?;
                    const reg_b = getRegistrableDomain(host_b.?) orelse host_b.?;

                    return std.mem.eql(u8, reg_a, reg_b);
                },
            }
        },
    }
}

// =============================================================================
// Tests
// =============================================================================

test "getRegistrableDomain simple" {
    try std.testing.expectEqualStrings("example.com", getRegistrableDomain("www.example.com").?);
    try std.testing.expectEqualStrings("example.com", getRegistrableDomain("example.com").?);
    try std.testing.expectEqualStrings("localhost", getRegistrableDomain("localhost").?);
}

test "getRegistrableDomain with subdomains" {
    try std.testing.expectEqualStrings("example.com", getRegistrableDomain("sub.www.example.com").?);
    try std.testing.expectEqualStrings("example.com", getRegistrableDomain("a.b.c.example.com").?);
}

test "getRegistrableDomain IP addresses return null" {
    try std.testing.expect(getRegistrableDomain("192.168.1.1") == null);
    try std.testing.expect(getRegistrableDomain("127.0.0.1") == null);
}

test "isSameSite same domain" {
    const allocator = std.testing.allocator;

    const a = try environment.parseOriginFromUrl(allocator, "https://www.example.com/path");
    defer a.deinit(allocator);

    const b = try environment.parseOriginFromUrl(allocator, "https://api.example.com/other");
    defer b.deinit(allocator);

    try std.testing.expect(isSameSite(a, b));
}

test "isSameSite different domains" {
    const allocator = std.testing.allocator;

    const a = try environment.parseOriginFromUrl(allocator, "https://example.com/");
    defer a.deinit(allocator);

    const b = try environment.parseOriginFromUrl(allocator, "https://other.com/");
    defer b.deinit(allocator);

    try std.testing.expect(!isSameSite(a, b));
}

test "isSameSite different schemes" {
    const allocator = std.testing.allocator;

    const a = try environment.parseOriginFromUrl(allocator, "https://example.com/");
    defer a.deinit(allocator);

    const b = try environment.parseOriginFromUrl(allocator, "http://example.com/");
    defer b.deinit(allocator);

    try std.testing.expect(!isSameSite(a, b));
}

test "isSchemelesslySameSite ignores scheme" {
    const allocator = std.testing.allocator;

    const a = try environment.parseOriginFromUrl(allocator, "https://example.com/");
    defer a.deinit(allocator);

    const b = try environment.parseOriginFromUrl(allocator, "http://example.com/");
    defer b.deinit(allocator);

    try std.testing.expect(isSchemelesslySameSite(a, b));
}

test "isSameOriginDomain delegates to sameOrigin" {
    const allocator = std.testing.allocator;

    const a = try environment.parseOriginFromUrl(allocator, "https://example.com/");
    defer a.deinit(allocator);

    const b = try environment.parseOriginFromUrl(allocator, "https://example.com/other");
    defer b.deinit(allocator);

    try std.testing.expect(isSameOriginDomain(a, b));
}
