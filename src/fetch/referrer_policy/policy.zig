//! W3C Referrer Policy Implementation
//!
//! Spec: https://w3c.github.io/webappsec-referrer-policy/
//!
//! This module implements the Referrer Policy enum and parsing.
//! Used by Fetch to determine the Referer header value.

const std = @import("std");

/// Referrer policy values per spec § 3.
///
/// These values determine how much referrer information is sent
/// with requests.
pub const ReferrerPolicy = enum {
    /// Empty string policy (use default).
    /// Spec: "The empty string"
    empty,

    /// Never send Referer header.
    /// Spec: "no-referrer"
    no_referrer,

    /// Send full URL to same-origin, nothing for HTTPS->HTTP downgrade.
    /// Spec: "no-referrer-when-downgrade"
    no_referrer_when_downgrade,

    /// Only send Referer for same-origin requests.
    /// Spec: "same-origin"
    same_origin,

    /// Send only origin (not path) for all requests.
    /// Spec: "origin"
    origin,

    /// Send only origin, nothing for HTTPS->HTTP downgrade.
    /// Spec: "strict-origin"
    strict_origin,

    /// Send full URL to same-origin, origin to cross-origin.
    /// Spec: "origin-when-cross-origin"
    origin_when_cross_origin,

    /// Send full URL to same-origin, origin to cross-origin,
    /// nothing for HTTPS->HTTP downgrade.
    /// Spec: "strict-origin-when-cross-origin"
    strict_origin_when_cross_origin,

    /// Always send full URL (unsafe).
    /// Spec: "unsafe-url"
    unsafe_url,

    const Self = @This();

    /// Parse a referrer policy string.
    ///
    /// Spec: § 4.3 "Parse a referrer policy from a Referrer-Policy header"
    /// (single token parsing)
    ///
    /// Returns null for invalid/unknown policies.
    pub fn parse(value: []const u8) ?Self {
        const trimmed = std.mem.trim(u8, value, " \t");
        if (trimmed.len == 0) return .empty;

        // Case-insensitive comparison
        if (eqlIgnoreCase(trimmed, "no-referrer")) return .no_referrer;
        if (eqlIgnoreCase(trimmed, "no-referrer-when-downgrade")) return .no_referrer_when_downgrade;
        if (eqlIgnoreCase(trimmed, "same-origin")) return .same_origin;
        if (eqlIgnoreCase(trimmed, "origin")) return .origin;
        if (eqlIgnoreCase(trimmed, "strict-origin")) return .strict_origin;
        if (eqlIgnoreCase(trimmed, "origin-when-cross-origin")) return .origin_when_cross_origin;
        if (eqlIgnoreCase(trimmed, "strict-origin-when-cross-origin")) return .strict_origin_when_cross_origin;
        if (eqlIgnoreCase(trimmed, "unsafe-url")) return .unsafe_url;

        return null; // Invalid policy
    }

    /// Get the default referrer policy.
    ///
    /// Spec: The default is "strict-origin-when-cross-origin"
    pub fn default() Self {
        return .strict_origin_when_cross_origin;
    }

    /// Convert policy to string representation.
    pub fn toString(self: Self) []const u8 {
        return switch (self) {
            .empty => "",
            .no_referrer => "no-referrer",
            .no_referrer_when_downgrade => "no-referrer-when-downgrade",
            .same_origin => "same-origin",
            .origin => "origin",
            .strict_origin => "strict-origin",
            .origin_when_cross_origin => "origin-when-cross-origin",
            .strict_origin_when_cross_origin => "strict-origin-when-cross-origin",
            .unsafe_url => "unsafe-url",
        };
    }
};

/// Parse Referrer-Policy header value.
///
/// Spec: § 4.3 "Parse a referrer policy from a Referrer-Policy header"
///
/// The header can contain comma-separated values for fallback.
/// Returns the LAST valid policy in the list, or null if none valid.
///
/// Example: "no-referrer, strict-origin" -> returns .strict_origin
pub fn parseReferrerPolicyHeader(header_value: []const u8) ?ReferrerPolicy {
    var result: ?ReferrerPolicy = null;

    var iter = std.mem.splitScalar(u8, header_value, ',');
    while (iter.next()) |token| {
        if (ReferrerPolicy.parse(token)) |policy| {
            // Skip empty policy tokens
            if (policy != .empty) {
                result = policy;
            }
        }
    }

    return result;
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

test "ReferrerPolicy.parse valid policies" {
    try std.testing.expectEqual(ReferrerPolicy.no_referrer, ReferrerPolicy.parse("no-referrer").?);
    try std.testing.expectEqual(ReferrerPolicy.no_referrer_when_downgrade, ReferrerPolicy.parse("no-referrer-when-downgrade").?);
    try std.testing.expectEqual(ReferrerPolicy.same_origin, ReferrerPolicy.parse("same-origin").?);
    try std.testing.expectEqual(ReferrerPolicy.origin, ReferrerPolicy.parse("origin").?);
    try std.testing.expectEqual(ReferrerPolicy.strict_origin, ReferrerPolicy.parse("strict-origin").?);
    try std.testing.expectEqual(ReferrerPolicy.origin_when_cross_origin, ReferrerPolicy.parse("origin-when-cross-origin").?);
    try std.testing.expectEqual(ReferrerPolicy.strict_origin_when_cross_origin, ReferrerPolicy.parse("strict-origin-when-cross-origin").?);
    try std.testing.expectEqual(ReferrerPolicy.unsafe_url, ReferrerPolicy.parse("unsafe-url").?);
}

test "ReferrerPolicy.parse case insensitive" {
    try std.testing.expectEqual(ReferrerPolicy.no_referrer, ReferrerPolicy.parse("No-Referrer").?);
    try std.testing.expectEqual(ReferrerPolicy.no_referrer, ReferrerPolicy.parse("NO-REFERRER").?);
    try std.testing.expectEqual(ReferrerPolicy.strict_origin, ReferrerPolicy.parse("STRICT-ORIGIN").?);
}

test "ReferrerPolicy.parse with whitespace" {
    try std.testing.expectEqual(ReferrerPolicy.no_referrer, ReferrerPolicy.parse("  no-referrer  ").?);
    try std.testing.expectEqual(ReferrerPolicy.origin, ReferrerPolicy.parse("\torigin\t").?);
}

test "ReferrerPolicy.parse empty string" {
    try std.testing.expectEqual(ReferrerPolicy.empty, ReferrerPolicy.parse("").?);
    try std.testing.expectEqual(ReferrerPolicy.empty, ReferrerPolicy.parse("   ").?);
}

test "ReferrerPolicy.parse invalid returns null" {
    try std.testing.expect(ReferrerPolicy.parse("invalid") == null);
    try std.testing.expect(ReferrerPolicy.parse("referrer") == null);
    try std.testing.expect(ReferrerPolicy.parse("no-ref") == null);
}

test "ReferrerPolicy.default" {
    try std.testing.expectEqual(ReferrerPolicy.strict_origin_when_cross_origin, ReferrerPolicy.default());
}

test "ReferrerPolicy.toString roundtrip" {
    const policies = [_]ReferrerPolicy{
        .no_referrer,
        .no_referrer_when_downgrade,
        .same_origin,
        .origin,
        .strict_origin,
        .origin_when_cross_origin,
        .strict_origin_when_cross_origin,
        .unsafe_url,
    };

    for (policies) |policy| {
        const str = policy.toString();
        const parsed = ReferrerPolicy.parse(str).?;
        try std.testing.expectEqual(policy, parsed);
    }
}

test "parseReferrerPolicyHeader single value" {
    try std.testing.expectEqual(ReferrerPolicy.no_referrer, parseReferrerPolicyHeader("no-referrer").?);
    try std.testing.expectEqual(ReferrerPolicy.origin, parseReferrerPolicyHeader("origin").?);
}

test "parseReferrerPolicyHeader comma-separated returns last valid" {
    // Spec says: return the LAST valid policy
    try std.testing.expectEqual(ReferrerPolicy.strict_origin, parseReferrerPolicyHeader("no-referrer, strict-origin").?);
    try std.testing.expectEqual(ReferrerPolicy.origin, parseReferrerPolicyHeader("unsafe-url, origin").?);
}

test "parseReferrerPolicyHeader with invalid tokens" {
    // Invalid tokens are skipped, last valid is returned
    try std.testing.expectEqual(ReferrerPolicy.no_referrer, parseReferrerPolicyHeader("invalid, no-referrer").?);
    try std.testing.expectEqual(ReferrerPolicy.origin, parseReferrerPolicyHeader("no-referrer, invalid, origin").?);
}

test "parseReferrerPolicyHeader all invalid returns null" {
    try std.testing.expect(parseReferrerPolicyHeader("invalid, unknown") == null);
}

test "parseReferrerPolicyHeader with whitespace" {
    try std.testing.expectEqual(ReferrerPolicy.origin, parseReferrerPolicyHeader("  no-referrer  ,  origin  ").?);
}
