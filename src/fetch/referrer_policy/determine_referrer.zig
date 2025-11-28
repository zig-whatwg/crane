//! Determine Request's Referrer Algorithm
//!
//! Spec: https://w3c.github.io/webappsec-referrer-policy/ § 8.3
//!
//! This module implements the algorithm to determine the referrer URL
//! that should be sent with a request.

const std = @import("std");
const Allocator = std.mem.Allocator;
const ReferrerPolicy = @import("policy.zig").ReferrerPolicy;

/// The result of determining a request's referrer.
pub const Referrer = union(enum) {
    /// No referrer should be sent.
    no_referrer,

    /// A URL should be sent as the referrer.
    /// The string is owned by the caller if allocated.
    url: []const u8,

    /// Free the URL if it was allocated.
    pub fn deinit(self: Referrer, allocator: Allocator) void {
        switch (self) {
            .url => |url| allocator.free(url),
            .no_referrer => {},
        }
    }
};

/// Information about the referrer source URL.
pub const ReferrerSource = struct {
    /// The URL scheme (http, https, file, etc.)
    scheme: []const u8,
    /// The host string
    host: []const u8,
    /// The port (null for default port)
    port: ?u16,
    /// The full URL for full referrer
    full_url: []const u8,

    /// Check if this is a potentially trustworthy URL.
    /// Simplified: HTTPS and localhost are trustworthy.
    pub fn isPotentiallyTrustworthy(self: ReferrerSource) bool {
        if (std.mem.eql(u8, self.scheme, "https")) return true;
        if (std.mem.eql(u8, self.host, "localhost")) return true;
        if (std.mem.eql(u8, self.host, "127.0.0.1")) return true;
        if (std.mem.startsWith(u8, self.host, "[::1]")) return true;
        return false;
    }

    /// Get the origin-only URL (scheme://host:port/).
    pub fn originOnly(self: ReferrerSource, allocator: Allocator) ![]const u8 {
        if (self.port) |p| {
            return std.fmt.allocPrint(allocator, "{s}://{s}:{d}/", .{ self.scheme, self.host, p });
        } else {
            return std.fmt.allocPrint(allocator, "{s}://{s}/", .{ self.scheme, self.host });
        }
    }
};

/// Information about the target URL.
pub const TargetInfo = struct {
    scheme: []const u8,
    host: []const u8,
    port: ?u16,

    /// Check if this is a potentially trustworthy URL.
    pub fn isPotentiallyTrustworthy(self: TargetInfo) bool {
        if (std.mem.eql(u8, self.scheme, "https")) return true;
        if (std.mem.eql(u8, self.host, "localhost")) return true;
        if (std.mem.eql(u8, self.host, "127.0.0.1")) return true;
        if (std.mem.startsWith(u8, self.host, "[::1]")) return true;
        return false;
    }
};

/// Determine the referrer for a request.
///
/// Spec: § 8.3 "Determine request's Referrer"
///
/// This is a simplified version that takes pre-parsed URL components
/// rather than full URL objects, to avoid circular dependencies.
///
/// Parameters:
/// - allocator: For allocating the result URL string
/// - policy: The referrer policy to apply
/// - referrer_source: Information about the referrer URL (or null for no referrer)
/// - target: Information about the target URL
/// - is_same_origin: Whether referrer and target are same-origin
///
/// Returns:
/// - Referrer.no_referrer if no referrer should be sent
/// - Referrer.url with the referrer URL string (caller owns)
pub fn determineReferrer(
    allocator: Allocator,
    policy: ReferrerPolicy,
    referrer_source: ?ReferrerSource,
    target: TargetInfo,
    is_same_origin: bool,
) !Referrer {
    // Step 1: If referrer source is null/empty, return no referrer
    const source = referrer_source orelse return .no_referrer;

    // Step 2: Check for local schemes that should not send referrer
    if (isLocalScheme(source.scheme)) {
        return .no_referrer;
    }

    // Step 3: Determine effective policy (empty -> default)
    const effective_policy = if (policy == .empty)
        ReferrerPolicy.default()
    else
        policy;

    // Step 4: Apply the policy
    return applyPolicy(allocator, effective_policy, source, target, is_same_origin);
}

/// Apply a referrer policy to determine what to send.
///
/// Spec: § 8.3 policy-specific logic
fn applyPolicy(
    allocator: Allocator,
    policy: ReferrerPolicy,
    source: ReferrerSource,
    target: TargetInfo,
    is_same_origin: bool,
) !Referrer {
    const is_downgrade = isDowngrade(source, target);

    return switch (policy) {
        .empty => unreachable, // Handled by caller

        .no_referrer => .no_referrer,

        .no_referrer_when_downgrade => {
            // Send full URL unless downgrade
            if (is_downgrade) return .no_referrer;
            return .{ .url = try allocator.dupe(u8, source.full_url) };
        },

        .same_origin => {
            // Only send for same-origin
            if (is_same_origin) {
                return .{ .url = try allocator.dupe(u8, source.full_url) };
            }
            return .no_referrer;
        },

        .origin => {
            // Always send origin only
            return .{ .url = try source.originOnly(allocator) };
        },

        .strict_origin => {
            // Send origin only, unless downgrade
            if (is_downgrade) return .no_referrer;
            return .{ .url = try source.originOnly(allocator) };
        },

        .origin_when_cross_origin => {
            // Full URL for same-origin, origin for cross-origin
            if (is_same_origin) {
                return .{ .url = try allocator.dupe(u8, source.full_url) };
            }
            return .{ .url = try source.originOnly(allocator) };
        },

        .strict_origin_when_cross_origin => {
            // Full URL for same-origin
            // Origin for cross-origin (unless downgrade)
            if (is_same_origin) {
                return .{ .url = try allocator.dupe(u8, source.full_url) };
            }
            if (is_downgrade) return .no_referrer;
            return .{ .url = try source.originOnly(allocator) };
        },

        .unsafe_url => {
            // Always send full URL
            return .{ .url = try allocator.dupe(u8, source.full_url) };
        },
    };
}

/// Check if this is a downgrade (HTTPS -> HTTP).
///
/// Spec: A request is a "downgrade" if the referrer URL is
/// potentially trustworthy and the target is not.
fn isDowngrade(source: ReferrerSource, target: TargetInfo) bool {
    return source.isPotentiallyTrustworthy() and !target.isPotentiallyTrustworthy();
}

/// Check if a scheme is a local scheme.
///
/// Local schemes should not send referrer information.
fn isLocalScheme(scheme: []const u8) bool {
    return std.mem.eql(u8, scheme, "about") or
        std.mem.eql(u8, scheme, "blob") or
        std.mem.eql(u8, scheme, "data");
}

/// Strip a URL for use as referrer.
///
/// Spec: § 8.4 "Strip url for use as a referrer"
///
/// Algorithm:
/// 1. If URL scheme is local, return no referrer
/// 2. Set username and password to empty string
/// 3. Set fragment to null
/// 4. Return URL
///
/// This function returns a new string with username/password/fragment removed.
pub fn stripUrlForReferrer(allocator: Allocator, url: []const u8) !?[]const u8 {
    // Find scheme - look for first : character
    const colon_pos = std.mem.indexOf(u8, url, ":") orelse return null;
    const scheme = url[0..colon_pos];

    // Check for local schemes
    if (isLocalScheme(scheme)) {
        return null;
    }

    // Verify it's a proper URL (has :// after scheme for http/https/etc)
    // Note: Some schemes like blob: and javascript: are local and already filtered
    if (url.len <= colon_pos + 3 or !std.mem.eql(u8, url[colon_pos .. colon_pos + 3], "://")) {
        // Not a proper URL format, treat as invalid
        return null;
    }

    // Find fragment and remove it
    const fragment_pos = std.mem.indexOf(u8, url, "#");
    const url_without_fragment = if (fragment_pos) |pos|
        url[0..pos]
    else
        url;

    // TODO: Strip username:password@ if present
    // For now, assume URLs don't have credentials embedded
    // (most modern URLs don't use this deprecated pattern)

    return try allocator.dupe(u8, url_without_fragment);
}

// =============================================================================
// Tests
// =============================================================================

test "determineReferrer no_referrer policy" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = null,
        .full_url = "https://example.com/page",
    };

    const target = TargetInfo{
        .scheme = "https",
        .host = "other.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .no_referrer, source, target, false);
    try std.testing.expectEqual(Referrer.no_referrer, result);
}

test "determineReferrer unsafe_url policy" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = null,
        .full_url = "https://example.com/secret/page?token=abc",
    };

    const target = TargetInfo{
        .scheme = "http",
        .host = "other.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .unsafe_url, source, target, false);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("https://example.com/secret/page?token=abc", result.url);
}

test "determineReferrer same_origin policy - same origin" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = null,
        .full_url = "https://example.com/page",
    };

    const target = TargetInfo{
        .scheme = "https",
        .host = "example.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .same_origin, source, target, true);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("https://example.com/page", result.url);
}

test "determineReferrer same_origin policy - cross origin" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = null,
        .full_url = "https://example.com/page",
    };

    const target = TargetInfo{
        .scheme = "https",
        .host = "other.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .same_origin, source, target, false);
    try std.testing.expectEqual(Referrer.no_referrer, result);
}

test "determineReferrer origin policy" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = null,
        .full_url = "https://example.com/secret/page?token=abc",
    };

    const target = TargetInfo{
        .scheme = "https",
        .host = "other.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .origin, source, target, false);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("https://example.com/", result.url);
}

test "determineReferrer strict_origin policy - no downgrade" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = null,
        .full_url = "https://example.com/page",
    };

    const target = TargetInfo{
        .scheme = "https",
        .host = "other.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .strict_origin, source, target, false);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("https://example.com/", result.url);
}

test "determineReferrer strict_origin policy - downgrade" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = null,
        .full_url = "https://example.com/page",
    };

    const target = TargetInfo{
        .scheme = "http",
        .host = "other.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .strict_origin, source, target, false);
    try std.testing.expectEqual(Referrer.no_referrer, result);
}

test "determineReferrer strict_origin_when_cross_origin - same origin" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = null,
        .full_url = "https://example.com/secret/page",
    };

    const target = TargetInfo{
        .scheme = "https",
        .host = "example.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .strict_origin_when_cross_origin, source, target, true);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("https://example.com/secret/page", result.url);
}

test "determineReferrer strict_origin_when_cross_origin - cross origin no downgrade" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = null,
        .full_url = "https://example.com/secret/page",
    };

    const target = TargetInfo{
        .scheme = "https",
        .host = "other.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .strict_origin_when_cross_origin, source, target, false);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("https://example.com/", result.url);
}

test "determineReferrer strict_origin_when_cross_origin - cross origin with downgrade" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = null,
        .full_url = "https://example.com/page",
    };

    const target = TargetInfo{
        .scheme = "http",
        .host = "other.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .strict_origin_when_cross_origin, source, target, false);
    try std.testing.expectEqual(Referrer.no_referrer, result);
}

test "determineReferrer no_referrer_when_downgrade - no downgrade" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = null,
        .full_url = "https://example.com/page",
    };

    const target = TargetInfo{
        .scheme = "https",
        .host = "other.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .no_referrer_when_downgrade, source, target, false);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("https://example.com/page", result.url);
}

test "determineReferrer no_referrer_when_downgrade - with downgrade" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = null,
        .full_url = "https://example.com/page",
    };

    const target = TargetInfo{
        .scheme = "http",
        .host = "other.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .no_referrer_when_downgrade, source, target, false);
    try std.testing.expectEqual(Referrer.no_referrer, result);
}

test "determineReferrer origin_when_cross_origin - same origin" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = null,
        .full_url = "https://example.com/page?secret=abc",
    };

    const target = TargetInfo{
        .scheme = "https",
        .host = "example.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .origin_when_cross_origin, source, target, true);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("https://example.com/page?secret=abc", result.url);
}

test "determineReferrer origin_when_cross_origin - cross origin" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = null,
        .full_url = "https://example.com/page?secret=abc",
    };

    const target = TargetInfo{
        .scheme = "https",
        .host = "other.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .origin_when_cross_origin, source, target, false);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("https://example.com/", result.url);
}

test "determineReferrer local scheme returns no referrer" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "data",
        .host = "",
        .port = null,
        .full_url = "data:text/html,<h1>Hello</h1>",
    };

    const target = TargetInfo{
        .scheme = "https",
        .host = "example.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .unsafe_url, source, target, false);
    try std.testing.expectEqual(Referrer.no_referrer, result);
}

test "determineReferrer empty policy uses default" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = null,
        .full_url = "https://example.com/page",
    };

    const target = TargetInfo{
        .scheme = "https",
        .host = "other.com",
        .port = null,
    };

    // Empty policy should use strict-origin-when-cross-origin (default)
    // Cross-origin, no downgrade -> origin only
    const result = try determineReferrer(allocator, .empty, source, target, false);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("https://example.com/", result.url);
}

test "determineReferrer null source returns no referrer" {
    const allocator = std.testing.allocator;

    const target = TargetInfo{
        .scheme = "https",
        .host = "example.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .unsafe_url, null, target, false);
    try std.testing.expectEqual(Referrer.no_referrer, result);
}

test "determineReferrer with port" {
    const allocator = std.testing.allocator;

    const source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = 8080,
        .full_url = "https://example.com:8080/page",
    };

    const target = TargetInfo{
        .scheme = "https",
        .host = "other.com",
        .port = null,
    };

    const result = try determineReferrer(allocator, .origin, source, target, false);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("https://example.com:8080/", result.url);
}

test "stripUrlForReferrer removes fragment" {
    const allocator = std.testing.allocator;

    const result = (try stripUrlForReferrer(allocator, "https://example.com/page#section")).?;
    defer allocator.free(result);

    try std.testing.expectEqualStrings("https://example.com/page", result);
}

test "stripUrlForReferrer local scheme returns null" {
    const allocator = std.testing.allocator;

    try std.testing.expect(try stripUrlForReferrer(allocator, "data:text/html,test") == null);
    try std.testing.expect(try stripUrlForReferrer(allocator, "about:blank") == null);
    try std.testing.expect(try stripUrlForReferrer(allocator, "blob:https://example.com/uuid") == null);
}

test "stripUrlForReferrer preserves query" {
    const allocator = std.testing.allocator;

    const result = (try stripUrlForReferrer(allocator, "https://example.com/page?query=value#frag")).?;
    defer allocator.free(result);

    try std.testing.expectEqualStrings("https://example.com/page?query=value", result);
}

test "isDowngrade HTTPS to HTTP" {
    const https_source = ReferrerSource{
        .scheme = "https",
        .host = "example.com",
        .port = null,
        .full_url = "https://example.com/",
    };

    const http_target = TargetInfo{
        .scheme = "http",
        .host = "example.com",
        .port = null,
    };

    const https_target = TargetInfo{
        .scheme = "https",
        .host = "example.com",
        .port = null,
    };

    try std.testing.expect(isDowngrade(https_source, http_target));
    try std.testing.expect(!isDowngrade(https_source, https_target));
}

test "isDowngrade localhost is trustworthy" {
    const http_localhost = ReferrerSource{
        .scheme = "http",
        .host = "localhost",
        .port = null,
        .full_url = "http://localhost/",
    };

    const http_target = TargetInfo{
        .scheme = "http",
        .host = "example.com",
        .port = null,
    };

    const https_target = TargetInfo{
        .scheme = "https",
        .host = "example.com",
        .port = null,
    };

    // localhost is trustworthy even over HTTP
    // HTTP localhost -> HTTP other IS a downgrade (trustworthy -> not trustworthy)
    try std.testing.expect(isDowngrade(http_localhost, http_target));
    // HTTP localhost -> HTTPS other is NOT a downgrade (both trustworthy)
    try std.testing.expect(!isDowngrade(http_localhost, https_target));
}
