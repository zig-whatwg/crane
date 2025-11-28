//! Cache-Control Header Parsing - HTTP Caching (RFC 7234)
//!
//! This module parses the Cache-Control header for HTTP caching decisions.
//!
//! Spec: https://httpwg.org/specs/rfc7234.html#header.cache-control
//!
//! Cache-Control directives:
//! - max-age: Maximum time a response is considered fresh
//! - s-maxage: Like max-age, but for shared caches only
//! - no-cache: Must revalidate before use
//! - no-store: Don't store the response at all
//! - must-revalidate: Must revalidate stale responses
//! - proxy-revalidate: Like must-revalidate for shared caches
//! - private: Response is for single user, not shared caches
//! - public: Response can be cached by any cache
//! - stale-while-revalidate: Can use stale while revalidating
//! - stale-if-error: Can use stale if origin returns error
//! - immutable: Response will not change during freshness lifetime

const std = @import("std");

/// Parsed Cache-Control header directives.
pub const CacheControl = struct {
    /// Maximum time (seconds) response is fresh (max-age directive)
    max_age: ?u64 = null,

    /// Maximum time for shared caches (s-maxage directive)
    s_maxage: ?u64 = null,

    /// Must revalidate before use (no-cache directive)
    no_cache: bool = false,

    /// Don't store response at all (no-store directive)
    no_store: bool = false,

    /// Must revalidate stale responses (must-revalidate directive)
    must_revalidate: bool = false,

    /// Must revalidate for shared caches (proxy-revalidate directive)
    proxy_revalidate: bool = false,

    /// Response is private to user (private directive)
    private_flag: bool = false,

    /// Response can be cached publicly (public directive)
    public: bool = false,

    /// Time (seconds) to serve stale while revalidating
    stale_while_revalidate: ?u64 = null,

    /// Time (seconds) to serve stale if origin errors
    stale_if_error: ?u64 = null,

    /// Response won't change during freshness (immutable directive)
    immutable: bool = false,

    /// no-transform: don't transform the response body
    no_transform: bool = false,

    /// only-if-cached: only return if cached (request directive)
    only_if_cached: bool = false,

    /// Parse a Cache-Control header value.
    ///
    /// Handles comma-separated directives with optional values.
    /// Unknown directives are ignored per spec.
    ///
    /// Examples:
    /// - "max-age=3600"
    /// - "no-cache, no-store"
    /// - "private, max-age=600, stale-while-revalidate=30"
    pub fn parse(value: []const u8) CacheControl {
        var result = CacheControl{};

        // Split by comma and process each directive
        var iter = std.mem.splitScalar(u8, value, ',');
        while (iter.next()) |part| {
            const trimmed = std.mem.trim(u8, part, " \t");
            if (trimmed.len == 0) continue;

            // Check for = sign to split name from value
            if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
                const name = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
                const val = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t\"");

                // Parse directives with values
                if (std.ascii.eqlIgnoreCase(name, "max-age")) {
                    result.max_age = std.fmt.parseInt(u64, val, 10) catch null;
                } else if (std.ascii.eqlIgnoreCase(name, "s-maxage")) {
                    result.s_maxage = std.fmt.parseInt(u64, val, 10) catch null;
                } else if (std.ascii.eqlIgnoreCase(name, "stale-while-revalidate")) {
                    result.stale_while_revalidate = std.fmt.parseInt(u64, val, 10) catch null;
                } else if (std.ascii.eqlIgnoreCase(name, "stale-if-error")) {
                    result.stale_if_error = std.fmt.parseInt(u64, val, 10) catch null;
                }
                // Note: no-cache can have field names, but we treat it as a flag
            } else {
                // Boolean directives (no value)
                if (std.ascii.eqlIgnoreCase(trimmed, "no-cache")) {
                    result.no_cache = true;
                } else if (std.ascii.eqlIgnoreCase(trimmed, "no-store")) {
                    result.no_store = true;
                } else if (std.ascii.eqlIgnoreCase(trimmed, "must-revalidate")) {
                    result.must_revalidate = true;
                } else if (std.ascii.eqlIgnoreCase(trimmed, "proxy-revalidate")) {
                    result.proxy_revalidate = true;
                } else if (std.ascii.eqlIgnoreCase(trimmed, "private")) {
                    result.private_flag = true;
                } else if (std.ascii.eqlIgnoreCase(trimmed, "public")) {
                    result.public = true;
                } else if (std.ascii.eqlIgnoreCase(trimmed, "immutable")) {
                    result.immutable = true;
                } else if (std.ascii.eqlIgnoreCase(trimmed, "no-transform")) {
                    result.no_transform = true;
                } else if (std.ascii.eqlIgnoreCase(trimmed, "only-if-cached")) {
                    result.only_if_cached = true;
                }
            }
        }

        return result;
    }

    /// Check if response should not be stored in cache.
    pub fn shouldNotStore(self: CacheControl) bool {
        return self.no_store;
    }

    /// Check if response must be revalidated before use.
    pub fn mustRevalidate(self: CacheControl, is_shared_cache: bool) bool {
        if (self.no_cache) return true;
        if (self.must_revalidate) return true;
        if (is_shared_cache and self.proxy_revalidate) return true;
        return false;
    }

    /// Check if response can be stored in shared cache.
    pub fn canStoreInSharedCache(self: CacheControl) bool {
        if (self.no_store) return false;
        if (self.private_flag) return false;
        return true;
    }

    /// Get effective max-age for cache freshness.
    /// For shared caches, s-maxage takes precedence over max-age.
    pub fn effectiveMaxAge(self: CacheControl, is_shared_cache: bool) ?u64 {
        if (is_shared_cache) {
            return self.s_maxage orelse self.max_age;
        }
        return self.max_age;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "CacheControl - parse max-age" {
    const cc = CacheControl.parse("max-age=3600");
    try std.testing.expectEqual(@as(?u64, 3600), cc.max_age);
    try std.testing.expect(!cc.no_cache);
    try std.testing.expect(!cc.no_store);
}

test "CacheControl - parse multiple directives" {
    const cc = CacheControl.parse("private, max-age=600, stale-while-revalidate=30");
    try std.testing.expectEqual(@as(?u64, 600), cc.max_age);
    try std.testing.expectEqual(@as(?u64, 30), cc.stale_while_revalidate);
    try std.testing.expect(cc.private_flag);
    try std.testing.expect(!cc.public);
}

test "CacheControl - parse no-cache no-store" {
    const cc = CacheControl.parse("no-cache, no-store");
    try std.testing.expect(cc.no_cache);
    try std.testing.expect(cc.no_store);
    try std.testing.expectEqual(@as(?u64, null), cc.max_age);
}

test "CacheControl - parse s-maxage" {
    const cc = CacheControl.parse("public, s-maxage=86400, max-age=3600");
    try std.testing.expect(cc.public);
    try std.testing.expectEqual(@as(?u64, 86400), cc.s_maxage);
    try std.testing.expectEqual(@as(?u64, 3600), cc.max_age);
}

test "CacheControl - parse must-revalidate" {
    const cc = CacheControl.parse("max-age=0, must-revalidate");
    try std.testing.expectEqual(@as(?u64, 0), cc.max_age);
    try std.testing.expect(cc.must_revalidate);
}

test "CacheControl - parse immutable" {
    const cc = CacheControl.parse("max-age=31536000, immutable");
    try std.testing.expectEqual(@as(?u64, 31536000), cc.max_age);
    try std.testing.expect(cc.immutable);
}

test "CacheControl - parse stale-if-error" {
    const cc = CacheControl.parse("max-age=600, stale-if-error=300");
    try std.testing.expectEqual(@as(?u64, 600), cc.max_age);
    try std.testing.expectEqual(@as(?u64, 300), cc.stale_if_error);
}

test "CacheControl - parse with extra whitespace" {
    const cc = CacheControl.parse("  max-age = 3600 , no-transform  ");
    try std.testing.expectEqual(@as(?u64, 3600), cc.max_age);
    try std.testing.expect(cc.no_transform);
}

test "CacheControl - parse quoted values" {
    const cc = CacheControl.parse("max-age=\"3600\"");
    try std.testing.expectEqual(@as(?u64, 3600), cc.max_age);
}

test "CacheControl - shouldNotStore" {
    const cc1 = CacheControl.parse("no-store");
    try std.testing.expect(cc1.shouldNotStore());

    const cc2 = CacheControl.parse("max-age=3600");
    try std.testing.expect(!cc2.shouldNotStore());
}

test "CacheControl - mustRevalidate" {
    const cc1 = CacheControl.parse("no-cache");
    try std.testing.expect(cc1.mustRevalidate(false));

    const cc2 = CacheControl.parse("must-revalidate");
    try std.testing.expect(cc2.mustRevalidate(false));

    const cc3 = CacheControl.parse("proxy-revalidate");
    try std.testing.expect(!cc3.mustRevalidate(false)); // private cache
    try std.testing.expect(cc3.mustRevalidate(true)); // shared cache

    const cc4 = CacheControl.parse("max-age=3600");
    try std.testing.expect(!cc4.mustRevalidate(false));
}

test "CacheControl - canStoreInSharedCache" {
    const cc1 = CacheControl.parse("private");
    try std.testing.expect(!cc1.canStoreInSharedCache());

    const cc2 = CacheControl.parse("no-store");
    try std.testing.expect(!cc2.canStoreInSharedCache());

    const cc3 = CacheControl.parse("public, max-age=3600");
    try std.testing.expect(cc3.canStoreInSharedCache());
}

test "CacheControl - effectiveMaxAge" {
    const cc = CacheControl.parse("s-maxage=86400, max-age=3600");

    // Shared cache uses s-maxage
    try std.testing.expectEqual(@as(?u64, 86400), cc.effectiveMaxAge(true));

    // Private cache uses max-age
    try std.testing.expectEqual(@as(?u64, 3600), cc.effectiveMaxAge(false));
}

test "CacheControl - effectiveMaxAge fallback" {
    const cc = CacheControl.parse("max-age=3600");

    // Shared cache falls back to max-age when no s-maxage
    try std.testing.expectEqual(@as(?u64, 3600), cc.effectiveMaxAge(true));
    try std.testing.expectEqual(@as(?u64, 3600), cc.effectiveMaxAge(false));
}

test "CacheControl - parse empty" {
    const cc = CacheControl.parse("");
    try std.testing.expectEqual(@as(?u64, null), cc.max_age);
    try std.testing.expect(!cc.no_cache);
    try std.testing.expect(!cc.no_store);
}

test "CacheControl - parse invalid values ignored" {
    const cc = CacheControl.parse("max-age=invalid, no-cache");
    try std.testing.expectEqual(@as(?u64, null), cc.max_age);
    try std.testing.expect(cc.no_cache);
}

test "CacheControl - case insensitive" {
    const cc = CacheControl.parse("MAX-AGE=3600, NO-CACHE, Private");
    try std.testing.expectEqual(@as(?u64, 3600), cc.max_age);
    try std.testing.expect(cc.no_cache);
    try std.testing.expect(cc.private_flag);
}
