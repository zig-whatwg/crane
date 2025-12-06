//! Cookie Jar - Collection and Storage Management
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//! RFC 6265bis: https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
//!
//! This module implements the CookieJar which manages a collection of cookies
//! with proper domain/path matching, expiration, and access control.

const std = @import("std");
const Cookie = @import("cookie.zig").Cookie;
const SameSite = @import("cookie.zig").SameSite;
const PartitionKey = @import("cookie.zig").PartitionKey;
const domain_matching = @import("domain_matching.zig");

/// Maximum cookies per domain (per RFC 6265bis recommendations)
pub const MAX_COOKIES_PER_DOMAIN: usize = 50;

/// Maximum total cookies in the jar
pub const MAX_TOTAL_COOKIES: usize = 3000;

/// SameSite context for cookie retrieval
pub const SameSiteContext = enum {
    /// Same-site request (first-party)
    same_site,
    /// Cross-site request with safe HTTP method (GET)
    cross_site_safe,
    /// Cross-site request with unsafe method (POST, etc.)
    cross_site_unsafe,
};

/// Options for retrieving cookies
pub const RetrieveOptions = struct {
    /// The request URL's host
    host: []const u8,
    /// The request URL's path
    path: []const u8 = "/",
    /// Whether this is an HTTP request (affects HttpOnly visibility)
    is_http: bool = false,
    /// Whether the connection is secure (HTTPS)
    is_secure: bool = false,
    /// SameSite context for the request
    same_site_context: SameSiteContext = .same_site,
    /// Partition key for CHIPS (null for unpartitioned access)
    partition_key: ?PartitionKey = null,
    /// Filter by cookie name (null for all)
    name: ?[]const u8 = null,
};

/// Cookie Jar - manages a collection of cookies
pub const CookieJar = struct {
    /// All cookies stored by a composite key
    cookies: std.ArrayListUnmanaged(Cookie),

    /// Allocator for the jar
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new cookie jar
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .cookies = .{},
            .allocator = allocator,
        };
    }

    /// Free all resources
    pub fn deinit(self: *Self) void {
        for (self.cookies.items) |*cookie| {
            cookie.deinit();
        }
        self.cookies.deinit(self.allocator);
    }

    /// Store a cookie, replacing any existing cookie with the same identity
    /// https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis#section-5.4
    pub fn store(self: *Self, cookie: Cookie) !void {
        // First, remove any existing cookie with the same identity
        var i: usize = 0;
        while (i < self.cookies.items.len) {
            if (self.cookies.items[i].hasSameIdentity(cookie)) {
                var removed = self.cookies.orderedRemove(i);
                removed.deinit();
                // Don't increment i since we removed an element
            } else {
                i += 1;
            }
        }

        // If the new cookie is already expired, don't store it
        // (this effectively deletes the old cookie)
        if (cookie.isExpired()) {
            return;
        }

        // Check limits and evict if necessary
        try self.evictIfNeeded(cookie.domain orelse "");

        // Clone and store the cookie
        const owned_cookie = try cookie.clone(self.allocator);
        try self.cookies.append(self.allocator, owned_cookie);
    }

    /// Retrieve cookies matching the given options
    /// https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis#section-5.6
    pub fn retrieve(self: *Self, options: RetrieveOptions) !std.ArrayListUnmanaged(Cookie) {
        var result = std.ArrayListUnmanaged(Cookie){};
        errdefer {
            for (result.items) |*c| c.deinit();
            result.deinit(self.allocator);
        }

        // Clean up expired cookies first
        self.removeExpired();

        for (self.cookies.items) |*cookie| {
            if (self.cookieMatches(cookie, options)) {
                // Update last access time
                cookie.touch();

                // Clone for return
                const cloned = try cookie.clone(self.allocator);
                try result.append(self.allocator, cloned);
            }
        }

        // Sort cookies per RFC 6265bis Section 5.6
        self.sortCookies(result.items);

        return result;
    }

    /// Delete cookies matching the given criteria
    pub fn delete(self: *Self, name: []const u8, domain: ?[]const u8, path: []const u8) usize {
        var deleted: usize = 0;
        var i: usize = 0;

        while (i < self.cookies.items.len) {
            const cookie = &self.cookies.items[i];

            const name_match = std.mem.eql(u8, cookie.name, name);
            const domain_match = if (domain) |d|
                if (cookie.domain) |cd| std.ascii.eqlIgnoreCase(cd, d) else false
            else
                true;
            const path_match = std.mem.eql(u8, cookie.path, path);

            if (name_match and domain_match and path_match) {
                var removed = self.cookies.orderedRemove(i);
                removed.deinit();
                deleted += 1;
            } else {
                i += 1;
            }
        }

        return deleted;
    }

    /// Clear all cookies
    pub fn clear(self: *Self) void {
        for (self.cookies.items) |*cookie| {
            cookie.deinit();
        }
        self.cookies.clearRetainingCapacity();
    }

    /// Get the number of cookies
    pub fn count(self: Self) usize {
        return self.cookies.items.len;
    }

    /// Remove all expired cookies
    pub fn removeExpired(self: *Self) void {
        var i: usize = 0;
        while (i < self.cookies.items.len) {
            if (self.cookies.items[i].isExpired()) {
                var removed = self.cookies.orderedRemove(i);
                removed.deinit();
            } else {
                i += 1;
            }
        }
    }

    /// Check if a cookie matches the retrieve options
    fn cookieMatches(self: *Self, cookie: *const Cookie, options: RetrieveOptions) bool {
        _ = self;

        // Name filter
        if (options.name) |name| {
            if (!std.mem.eql(u8, cookie.name, name)) {
                return false;
            }
        }

        // Domain matching
        if (cookie.host_only) {
            // Host-only cookies require exact match
            if (!std.ascii.eqlIgnoreCase(options.host, cookie.domain orelse options.host)) {
                return false;
            }
        } else {
            // Domain cookies use domain-matching
            if (cookie.domain) |domain| {
                if (!domain_matching.domainMatches(options.host, domain)) {
                    return false;
                }
            }
        }

        // Path matching
        if (!domain_matching.pathMatches(options.path, cookie.path)) {
            return false;
        }

        // Secure attribute: only send secure cookies over HTTPS
        if (cookie.secure and !options.is_secure) {
            return false;
        }

        // HttpOnly: only visible to HTTP requests, not JavaScript
        if (cookie.http_only and !options.is_http) {
            return false;
        }

        // SameSite filtering
        switch (cookie.same_site) {
            .strict => {
                // Strict cookies only sent in same-site context
                if (options.same_site_context != .same_site) {
                    return false;
                }
            },
            .lax => {
                // Lax cookies sent in same-site or safe cross-site
                if (options.same_site_context == .cross_site_unsafe) {
                    return false;
                }
            },
            .none => {
                // None cookies require Secure attribute
                if (!cookie.secure) {
                    return false;
                }
            },
        }

        // Partitioned cookie isolation (CHIPS)
        if (cookie.partition_key) |pk| {
            if (options.partition_key) |req_pk| {
                if (!pk.eql(req_pk)) {
                    return false;
                }
            } else {
                // Partitioned cookie but no partition key in request
                return false;
            }
        }

        return true;
    }

    /// Sort cookies per RFC 6265bis Section 5.6:
    /// 1. Longer paths come first
    /// 2. Earlier creation-time comes first (for same path length)
    fn sortCookies(_: *Self, cookies: []Cookie) void {
        std.mem.sort(Cookie, cookies, {}, struct {
            fn lessThan(_: void, a: Cookie, b: Cookie) bool {
                // First by path length (longer first)
                if (a.path.len != b.path.len) {
                    return a.path.len > b.path.len;
                }
                // Then by creation time (earlier first)
                return a.creation_time < b.creation_time;
            }
        }.lessThan);
    }

    /// Evict cookies if limits are exceeded
    fn evictIfNeeded(self: *Self, domain: []const u8) !void {
        // Count cookies for this domain
        var domain_count: usize = 0;
        for (self.cookies.items) |cookie| {
            if (cookie.domain) |d| {
                if (std.ascii.eqlIgnoreCase(d, domain)) {
                    domain_count += 1;
                }
            }
        }

        // Evict from domain if over limit
        if (domain_count >= MAX_COOKIES_PER_DOMAIN) {
            self.evictFromDomain(domain, 1);
        }

        // Evict globally if over total limit
        if (self.cookies.items.len >= MAX_TOTAL_COOKIES) {
            self.evictOldest(1);
        }
    }

    /// Evict cookies from a specific domain
    /// Priority: expired > oldest last-accessed > earliest expiring
    fn evictFromDomain(self: *Self, domain: []const u8, evict_count: usize) void {
        var evicted: usize = 0;

        // First pass: remove expired
        var i: usize = 0;
        while (i < self.cookies.items.len and evicted < evict_count) {
            const cookie = &self.cookies.items[i];
            const matches_domain = if (cookie.domain) |d|
                std.ascii.eqlIgnoreCase(d, domain)
            else
                false;

            if (matches_domain and cookie.isExpired()) {
                var removed = self.cookies.orderedRemove(i);
                removed.deinit();
                evicted += 1;
            } else {
                i += 1;
            }
        }

        // Second pass: remove oldest last-accessed
        while (evicted < evict_count) {
            var oldest_idx: ?usize = null;
            var oldest_time: i64 = std.math.maxInt(i64);

            for (self.cookies.items, 0..) |cookie, idx| {
                const matches_domain = if (cookie.domain) |d|
                    std.ascii.eqlIgnoreCase(d, domain)
                else
                    false;

                if (matches_domain and cookie.last_access_time < oldest_time) {
                    oldest_time = cookie.last_access_time;
                    oldest_idx = idx;
                }
            }

            if (oldest_idx) |idx| {
                var removed = self.cookies.orderedRemove(idx);
                removed.deinit();
                evicted += 1;
            } else {
                break;
            }
        }
    }

    /// Evict the oldest cookies globally
    fn evictOldest(self: *Self, evict_count: usize) void {
        var evicted: usize = 0;

        // First pass: remove expired
        var i: usize = 0;
        while (i < self.cookies.items.len and evicted < evict_count) {
            if (self.cookies.items[i].isExpired()) {
                var removed = self.cookies.orderedRemove(i);
                removed.deinit();
                evicted += 1;
            } else {
                i += 1;
            }
        }

        // Second pass: remove oldest last-accessed
        while (evicted < evict_count and self.cookies.items.len > 0) {
            var oldest_idx: usize = 0;
            var oldest_time: i64 = std.math.maxInt(i64);

            for (self.cookies.items, 0..) |cookie, idx| {
                if (cookie.last_access_time < oldest_time) {
                    oldest_time = cookie.last_access_time;
                    oldest_idx = idx;
                }
            }

            var removed = self.cookies.orderedRemove(oldest_idx);
            removed.deinit();
            evicted += 1;
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "CookieJar - basic store and retrieve" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // Create and store a cookie
    var cookie = try Cookie.init(allocator, "session", "abc123");
    defer cookie.deinit();
    cookie.secure = false;
    try cookie.setDomain("example.com");

    try jar.store(cookie);
    try std.testing.expectEqual(@as(usize, 1), jar.count());

    // Retrieve it
    var cookies = try jar.retrieve(.{
        .host = "example.com",
        .path = "/",
        .is_http = true,
    });
    defer {
        for (cookies.items) |*c| c.deinit();
        cookies.deinit(allocator);
    }

    try std.testing.expectEqual(@as(usize, 1), cookies.items.len);
    try std.testing.expectEqualStrings("session", cookies.items[0].name);
    try std.testing.expectEqualStrings("abc123", cookies.items[0].value);
}

test "CookieJar - deduplication" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // Store first cookie
    var cookie1 = try Cookie.init(allocator, "session", "value1");
    defer cookie1.deinit();
    try cookie1.setDomain("example.com");
    try jar.store(cookie1);

    // Store second cookie with same identity but different value
    var cookie2 = try Cookie.init(allocator, "session", "value2");
    defer cookie2.deinit();
    try cookie2.setDomain("example.com");
    try jar.store(cookie2);

    // Should still only have one cookie
    try std.testing.expectEqual(@as(usize, 1), jar.count());

    // Retrieve and verify it's the new value
    var cookies = try jar.retrieve(.{
        .host = "example.com",
        .is_http = true,
    });
    defer {
        for (cookies.items) |*c| c.deinit();
        cookies.deinit(allocator);
    }

    try std.testing.expectEqualStrings("value2", cookies.items[0].value);
}

test "CookieJar - domain matching" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // Store a domain cookie
    var cookie = try Cookie.init(allocator, "token", "xyz");
    defer cookie.deinit();
    try cookie.setDomain("example.com");
    try jar.store(cookie);

    // Should match subdomain
    var cookies = try jar.retrieve(.{
        .host = "www.example.com",
        .is_http = true,
    });
    defer {
        for (cookies.items) |*c| c.deinit();
        cookies.deinit(allocator);
    }

    try std.testing.expectEqual(@as(usize, 1), cookies.items.len);
}

test "CookieJar - path matching" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // Store cookies with different paths
    var cookie1 = try Cookie.init(allocator, "root", "1");
    defer cookie1.deinit();
    try cookie1.setDomain("example.com");
    try cookie1.setPath("/");
    try jar.store(cookie1);

    var cookie2 = try Cookie.init(allocator, "app", "2");
    defer cookie2.deinit();
    try cookie2.setDomain("example.com");
    try cookie2.setPath("/app");
    try jar.store(cookie2);

    // Request to /app should get both
    var cookies1 = try jar.retrieve(.{
        .host = "example.com",
        .path = "/app/page",
        .is_http = true,
    });
    defer {
        for (cookies1.items) |*c| c.deinit();
        cookies1.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 2), cookies1.items.len);

    // Request to /other should only get root
    var cookies2 = try jar.retrieve(.{
        .host = "example.com",
        .path = "/other",
        .is_http = true,
    });
    defer {
        for (cookies2.items) |*c| c.deinit();
        cookies2.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 1), cookies2.items.len);
    try std.testing.expectEqualStrings("root", cookies2.items[0].name);
}

test "CookieJar - HttpOnly filtering" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // Store an HttpOnly cookie
    var cookie = try Cookie.init(allocator, "session", "secret");
    defer cookie.deinit();
    try cookie.setDomain("example.com");
    cookie.http_only = true;
    try jar.store(cookie);

    // HTTP request should see it
    var http_cookies = try jar.retrieve(.{
        .host = "example.com",
        .is_http = true,
    });
    defer {
        for (http_cookies.items) |*c| c.deinit();
        http_cookies.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 1), http_cookies.items.len);

    // Non-HTTP (JavaScript) should not see it
    var js_cookies = try jar.retrieve(.{
        .host = "example.com",
        .is_http = false,
    });
    defer {
        for (js_cookies.items) |*c| c.deinit();
        js_cookies.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 0), js_cookies.items.len);
}

test "CookieJar - Secure filtering" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // Store a Secure cookie
    var cookie = try Cookie.init(allocator, "token", "secure123");
    defer cookie.deinit();
    try cookie.setDomain("example.com");
    cookie.secure = true;
    try jar.store(cookie);

    // HTTPS should see it
    var secure_cookies = try jar.retrieve(.{
        .host = "example.com",
        .is_http = true,
        .is_secure = true,
    });
    defer {
        for (secure_cookies.items) |*c| c.deinit();
        secure_cookies.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 1), secure_cookies.items.len);

    // HTTP should not see it
    var insecure_cookies = try jar.retrieve(.{
        .host = "example.com",
        .is_http = true,
        .is_secure = false,
    });
    defer {
        for (insecure_cookies.items) |*c| c.deinit();
        insecure_cookies.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 0), insecure_cookies.items.len);
}

test "CookieJar - SameSite filtering" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // Store cookies with different SameSite values
    var strict_cookie = try Cookie.init(allocator, "strict", "1");
    defer strict_cookie.deinit();
    try strict_cookie.setDomain("example.com");
    strict_cookie.same_site = .strict;
    try jar.store(strict_cookie);

    var lax_cookie = try Cookie.init(allocator, "lax", "2");
    defer lax_cookie.deinit();
    try lax_cookie.setDomain("example.com");
    lax_cookie.same_site = .lax;
    try jar.store(lax_cookie);

    // Same-site request should get both
    var same_site = try jar.retrieve(.{
        .host = "example.com",
        .is_http = true,
        .same_site_context = .same_site,
    });
    defer {
        for (same_site.items) |*c| c.deinit();
        same_site.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 2), same_site.items.len);

    // Cross-site safe should only get lax
    var cross_safe = try jar.retrieve(.{
        .host = "example.com",
        .is_http = true,
        .same_site_context = .cross_site_safe,
    });
    defer {
        for (cross_safe.items) |*c| c.deinit();
        cross_safe.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 1), cross_safe.items.len);
    try std.testing.expectEqualStrings("lax", cross_safe.items[0].name);

    // Cross-site unsafe should get neither
    var cross_unsafe = try jar.retrieve(.{
        .host = "example.com",
        .is_http = true,
        .same_site_context = .cross_site_unsafe,
    });
    defer {
        for (cross_unsafe.items) |*c| c.deinit();
        cross_unsafe.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 0), cross_unsafe.items.len);
}

test "CookieJar - delete" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // Store cookies
    var cookie1 = try Cookie.init(allocator, "a", "1");
    defer cookie1.deinit();
    try cookie1.setDomain("example.com");
    try jar.store(cookie1);

    var cookie2 = try Cookie.init(allocator, "b", "2");
    defer cookie2.deinit();
    try cookie2.setDomain("example.com");
    try jar.store(cookie2);

    try std.testing.expectEqual(@as(usize, 2), jar.count());

    // Delete one
    const deleted = jar.delete("a", "example.com", "/");
    try std.testing.expectEqual(@as(usize, 1), deleted);
    try std.testing.expectEqual(@as(usize, 1), jar.count());
}

test "CookieJar - expired cookies" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // Store an expired cookie (shouldn't be stored)
    var expired = try Cookie.init(allocator, "old", "data");
    defer expired.deinit();
    try expired.setDomain("example.com");
    expired.expiry_time = std.time.milliTimestamp() - 1000; // In the past
    try jar.store(expired);

    // Should not be stored
    try std.testing.expectEqual(@as(usize, 0), jar.count());
}

test "CookieJar - sorting" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // Store cookies with different paths (longer should come first)
    var short = try Cookie.init(allocator, "short", "1");
    defer short.deinit();
    try short.setDomain("example.com");
    try short.setPath("/a");
    try jar.store(short);

    // Create second cookie with manually different creation time
    var long = try Cookie.init(allocator, "long", "2");
    long.creation_time = short.creation_time + 1000; // Ensure different creation time
    defer long.deinit();
    try long.setDomain("example.com");
    try long.setPath("/a/b/c");
    try jar.store(long);

    var cookies = try jar.retrieve(.{
        .host = "example.com",
        .path = "/a/b/c/d",
        .is_http = true,
    });
    defer {
        for (cookies.items) |*c| c.deinit();
        cookies.deinit(allocator);
    }

    // Longer path should come first
    try std.testing.expectEqual(@as(usize, 2), cookies.items.len);
    try std.testing.expectEqualStrings("long", cookies.items[0].name);
    try std.testing.expectEqualStrings("short", cookies.items[1].name);
}
