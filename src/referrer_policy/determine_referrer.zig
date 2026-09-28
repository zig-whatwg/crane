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

    /// Check if this is a potentially trustworthy URL (see
    /// `isPotentiallyTrustworthyOrigin`).
    pub fn isPotentiallyTrustworthy(self: ReferrerSource) bool {
        return isPotentiallyTrustworthyOrigin(self.scheme, self.host);
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

    /// Check if this is a potentially trustworthy URL (see
    /// `isPotentiallyTrustworthyOrigin`).
    pub fn isPotentiallyTrustworthy(self: TargetInfo) bool {
        return isPotentiallyTrustworthyOrigin(self.scheme, self.host);
    }
};

/// Secure Contexts "Is origin potentially trustworthy?" for a tuple origin
/// given as its scheme and serialized host (an IPv6 host in brackets).
///
/// Spec: https://w3c.github.io/webappsec-secure-contexts/#is-origin-trustworthy
pub fn isPotentiallyTrustworthyOrigin(scheme: []const u8, host: []const u8) bool {
    // 3. If origin's scheme is either "https" or "wss", return "Potentially
    //    Trustworthy".
    if (std.mem.eql(u8, scheme, "https") or std.mem.eql(u8, scheme, "wss")) return true;
    // 4. If origin's host matches one of the CIDR notations 127.0.0.0/8 or
    //    ::1/128, return "Potentially Trustworthy".
    if (std.mem.startsWith(u8, host, "127.") and isIPv4(host)) return true;
    if (std.mem.eql(u8, host, "[::1]")) return true;
    // 5. If the user agent conforms to the name resolution rules in
    //    [let-localhost-be-localhost] and one of the following is true:
    //    origin's host is "localhost" or "localhost.", or ends with
    //    ".localhost" or ".localhost.".
    if (std.mem.eql(u8, host, "localhost") or std.mem.eql(u8, host, "localhost.")) return true;
    if (std.mem.endsWith(u8, host, ".localhost") or std.mem.endsWith(u8, host, ".localhost.")) return true;
    // 6. If origin's scheme is "file", return "Potentially Trustworthy".
    if (std.mem.eql(u8, scheme, "file")) return true;
    // 8. Return "Not Trustworthy".
    return false;
}

/// A serialized host that is an IPv4 address: four dotted decimals.
fn isIPv4(host: []const u8) bool {
    var parts: usize = 0;
    var it = std.mem.splitScalar(u8, host, '.');
    while (it.next()) |part| {
        parts += 1;
        if (part.len == 0) return false;
        for (part) |c| if (!std.ascii.isDigit(c)) return false;
    }
    return parts == 4;
}

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
    // Steps 1-3: the caller resolves referrerSource - `referrer_source`,
    // null when there is none - and step 4 strips it: `full_url` is
    // referrerURL (`stripUrlForReferrer`).
    const source = referrer_source orelse return .no_referrer;
    // Stripping a URL with a local scheme gives no referrer (8.4 step 2).
    if (isLocalScheme(source.scheme)) {
        return .no_referrer;
    }

    // Step 5: Let referrerOrigin be the result of stripping referrerSource
    // for use as a referrer, with the origin-only flag set to true.
    const referrer_origin = try source.originOnly(allocator);
    defer allocator.free(referrer_origin);

    // Step 6: If the result of serializing referrerURL is a string whose
    // length is greater than 4096, set referrerURL to referrerOrigin.
    const referrer_url = if (source.full_url.len > 4096) referrer_origin else source.full_url;

    // The empty policy is the default (Fetch main fetch step 8 replaces it
    // before this runs).
    const effective_policy = if (policy == .empty)
        ReferrerPolicy.default()
    else
        policy;

    // Step 8: Execute the statements corresponding to the value of policy.
    return applyPolicy(allocator, effective_policy, source, referrer_url, referrer_origin, target, is_same_origin);
}

/// Referrer Policy 8.3 step 8: what `policy` sends - `referrer_url` or
/// `referrer_origin` (copied), or no referrer.
fn applyPolicy(
    allocator: Allocator,
    policy: ReferrerPolicy,
    source: ReferrerSource,
    referrer_url: []const u8,
    referrer_origin: []const u8,
    target: TargetInfo,
    is_same_origin: bool,
) !Referrer {
    const is_downgrade = isDowngrade(source, target);
    const chosen: ?[]const u8 = switch (policy) {
        .empty => unreachable, // Handled by caller

        // "no-referrer": Return no referrer.
        .no_referrer => null,

        // "no-referrer-when-downgrade": If referrerURL is a potentially
        // trustworthy URL and request's current URL is not, then return no
        // referrer. Return referrerURL.
        .no_referrer_when_downgrade => if (is_downgrade) null else referrer_url,

        // "same-origin": If the origin of referrerURL and the origin of
        // request's current URL are the same, then return referrerURL.
        // Return no referrer.
        .same_origin => if (is_same_origin) referrer_url else null,

        // "origin": Return referrerOrigin.
        .origin => referrer_origin,

        // "strict-origin": If referrerURL is a potentially trustworthy URL
        // and request's current URL is not, then return no referrer. Return
        // referrerOrigin.
        .strict_origin => if (is_downgrade) null else referrer_origin,

        // "origin-when-cross-origin": If the origin of referrerURL and the
        // origin of request's current URL are the same, then return
        // referrerURL. Return referrerOrigin.
        .origin_when_cross_origin => if (is_same_origin) referrer_url else referrer_origin,

        // "strict-origin-when-cross-origin": 1. If the origin of referrerURL
        // and the origin of request's current URL are the same, then return
        // referrerURL. 2. If referrerURL is a potentially trustworthy URL and
        // request's current URL is not, then return no referrer. 3. Return
        // referrerOrigin.
        .strict_origin_when_cross_origin => if (is_same_origin) referrer_url else if (is_downgrade) null else referrer_origin,

        // "unsafe-url": Return referrerURL.
        .unsafe_url => referrer_url,
    };
    const value = chosen orelse return .no_referrer;
    return .{ .url = try allocator.dupe(u8, value) };
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

/// Strip a URL for use as referrer - without the origin-only flag
/// (`ReferrerSource.originOnly` is that form).
///
/// Spec: § 8.4 "Strip url for use as a referrer"
///
/// 1. If url is null, return no referrer.
/// 2. If url's scheme is a local scheme, then return no referrer.
/// 3. Set url's username to the empty string.
/// 4. Set url's password to the empty string.
/// 5. Set url's fragment to null.
/// 7. Return url.
///
/// `url` is a serialized URL (the URL parser's output, so its authority is
/// canonical); null is "no referrer". The result is owned.
pub fn stripUrlForReferrer(allocator: Allocator, url: []const u8) !?[]const u8 {
    // Find scheme - look for first : character
    const colon_pos = std.mem.indexOf(u8, url, ":") orelse return null;
    const scheme = url[0..colon_pos];

    // Step 2: If url's scheme is a local scheme, then return no referrer.
    if (isLocalScheme(scheme)) {
        return null;
    }

    // Verify it's a proper URL (has :// after scheme for http/https/etc)
    // Note: Some schemes like blob: and javascript: are local and already filtered
    if (url.len <= colon_pos + 3 or !std.mem.eql(u8, url[colon_pos .. colon_pos + 3], "://")) {
        // Not a proper URL format, treat as invalid
        return null;
    }

    // Step 5: Set url's fragment to null.
    const fragment_pos = std.mem.indexOf(u8, url, "#");
    const url_without_fragment = if (fragment_pos) |pos|
        url[0..pos]
    else
        url;

    // Steps 3-4: Set url's username and password to the empty string. In a
    // serialized URL they are the userinfo before the last "@" of the
    // authority, which ends at the first "/", "?" or "#" after "://".
    const authority_start = colon_pos + 3;
    const authority_len = std.mem.indexOfAny(u8, url_without_fragment[authority_start..], "/?#") orelse url_without_fragment.len - authority_start;
    const authority = url_without_fragment[authority_start .. authority_start + authority_len];
    if (std.mem.lastIndexOfScalar(u8, authority, '@')) |at| {
        return try std.mem.concat(allocator, u8, &.{ url_without_fragment[0..authority_start], url_without_fragment[authority_start + at + 1 ..] });
    }

    // Step 7: Return url.
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
