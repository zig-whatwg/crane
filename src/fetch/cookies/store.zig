//! Cookie Store per RFC 6265bis
//!
//! Spec: https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
//!
//! This module implements an in-memory cookie store for Fetch's
//! credentials handling.
//!
//! TODO(cookie-store-api): This internal cookie store should integrate with
//! the Cookie Store API when implemented.
//! See: https://wicg.github.io/cookie-store/

const std = @import("std");
const Allocator = std.mem.Allocator;
const Cookie = @import("cookie.zig").Cookie;
const SameSite = @import("cookie.zig").SameSite;
const matching = @import("matching.zig");
const parsing = @import("parsing.zig");
const same_site = @import("same_site.zig");

/// In-memory cookie store.
pub const CookieStore = struct {
    allocator: Allocator,

    /// All stored cookies
    cookies: std.ArrayListUnmanaged(Cookie),

    /// Maximum cookies per domain
    max_cookies_per_domain: usize = 50,

    /// Maximum total cookies
    max_total_cookies: usize = 3000,

    const Self = @This();

    /// Initialize an empty cookie store.
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .cookies = .{},
        };
    }

    /// Free all cookies and the store.
    pub fn deinit(self: *Self) void {
        for (self.cookies.items) |*cookie| {
            cookie.deinit();
        }
        self.cookies.deinit(self.allocator);
    }

    /// Get cookies matching a request URL.
    ///
    /// Parameters:
    /// - host: The request host
    /// - path: The request path
    /// - is_secure: Whether the request is over HTTPS
    /// - same_site_status: Same-site status for the request
    /// - request_type: Type of request (for SameSite evaluation)
    ///
    /// Returns a list of matching cookies (caller must free the list, not the cookies).
    pub fn getCookiesForRequest(
        self: *Self,
        host: []const u8,
        path: []const u8,
        is_secure: bool,
        same_site_status: same_site.SameSiteStatus,
        request_type: same_site.RequestType,
    ) ![]Cookie {
        var result: std.ArrayListUnmanaged(Cookie) = .{};
        errdefer result.deinit(self.allocator);

        // First, remove expired cookies
        self.removeExpired();

        for (self.cookies.items) |*cookie| {
            // Check Secure attribute
            if (cookie.secure_only and !is_secure) continue;

            // Check domain
            if (!matching.domainMatches(cookie.*, host)) continue;

            // Check path
            if (!matching.pathMatches(cookie.path, path)) continue;

            // Check SameSite
            if (!same_site.shouldIncludeCookie(
                cookie.same_site,
                same_site_status,
                request_type,
                cookie.secure_only,
            )) continue;

            // Cookie matches - add to result
            try result.append(self.allocator, cookie.*);

            // Update last access time
            cookie.touch();
        }

        // Sort cookies: longest path first, then earliest creation time
        const items = result.items;
        std.mem.sort(Cookie, items, {}, compareCookiesForHeader);

        return result.toOwnedSlice(self.allocator);
    }

    /// Store a cookie from a Set-Cookie header.
    ///
    /// Parameters:
    /// - set_cookie_value: The Set-Cookie header value
    /// - host: The request host
    /// - path: The request path
    /// - is_secure: Whether the request is over HTTPS
    pub fn setCookie(
        self: *Self,
        set_cookie_value: []const u8,
        host: []const u8,
        path: []const u8,
        is_secure: bool,
    ) !void {
        // Parse the Set-Cookie header
        var cookie = (try parsing.parseSetCookie(
            self.allocator,
            set_cookie_value,
            host,
            path,
        )) orelse return;
        errdefer cookie.deinit();

        // Reject Secure cookies on insecure connections
        if (cookie.secure_only and !is_secure) {
            cookie.deinit();
            return;
        }

        // Reject SameSite=None without Secure
        if (cookie.same_site == .none and !cookie.secure_only) {
            cookie.deinit();
            return;
        }

        // Check if this is an update to existing cookie
        const existing_idx = self.findCookie(cookie.name, cookie.domain, cookie.path);

        if (existing_idx) |idx| {
            // Update existing cookie
            var old = self.cookies.items[idx];
            cookie.creation_time = old.creation_time; // Preserve creation time
            old.deinit();
            self.cookies.items[idx] = cookie;
        } else {
            // New cookie - check limits before adding
            try self.evictIfNeeded(cookie.domain);
            try self.cookies.append(self.allocator, cookie);
        }
    }

    /// Remove expired cookies.
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

    /// Clear all cookies.
    pub fn clear(self: *Self) void {
        for (self.cookies.items) |*cookie| {
            cookie.deinit();
        }
        self.cookies.clearRetainingCapacity();
    }

    /// Clear cookies for a specific domain.
    pub fn clearDomain(self: *Self, domain: []const u8) void {
        var i: usize = 0;
        while (i < self.cookies.items.len) {
            const cookie = &self.cookies.items[i];
            if (cookie.domain) |d| {
                if (eqlIgnoreCase(d, domain) or matching.domainMatch(domain, d)) {
                    var removed = self.cookies.orderedRemove(i);
                    removed.deinit();
                    continue;
                }
            }
            i += 1;
        }
    }

    /// Get the number of stored cookies.
    pub fn count(self: *const Self) usize {
        return self.cookies.items.len;
    }

    // === Private helpers ===

    fn findCookie(
        self: *Self,
        name: []const u8,
        domain: ?[]const u8,
        path: []const u8,
    ) ?usize {
        for (self.cookies.items, 0..) |cookie, i| {
            if (!eqlIgnoreCase(cookie.name, name)) continue;
            if (!std.mem.eql(u8, cookie.path, path)) continue;

            const cookie_domain = cookie.domain orelse continue;
            const target_domain = domain orelse continue;
            if (!eqlIgnoreCase(cookie_domain, target_domain)) continue;

            return i;
        }
        return null;
    }

    fn evictIfNeeded(self: *Self, domain: ?[]const u8) !void {
        // Check per-domain limit
        if (domain) |d| {
            var domain_count: usize = 0;
            for (self.cookies.items) |cookie| {
                if (cookie.domain) |cd| {
                    if (eqlIgnoreCase(cd, d)) {
                        domain_count += 1;
                    }
                }
            }

            if (domain_count >= self.max_cookies_per_domain) {
                self.evictOldestForDomain(d);
            }
        }

        // Check total limit
        while (self.cookies.items.len >= self.max_total_cookies) {
            self.evictOldest();
        }
    }

    fn evictOldestForDomain(self: *Self, domain: []const u8) void {
        var oldest_idx: ?usize = null;
        var oldest_time: i64 = std.math.maxInt(i64);

        for (self.cookies.items, 0..) |cookie, i| {
            if (cookie.domain) |d| {
                if (eqlIgnoreCase(d, domain) and cookie.last_access_time < oldest_time) {
                    oldest_time = cookie.last_access_time;
                    oldest_idx = i;
                }
            }
        }

        if (oldest_idx) |idx| {
            var removed = self.cookies.orderedRemove(idx);
            removed.deinit();
        }
    }

    fn evictOldest(self: *Self) void {
        if (self.cookies.items.len == 0) return;

        var oldest_idx: usize = 0;
        var oldest_time: i64 = self.cookies.items[0].last_access_time;

        for (self.cookies.items[1..], 1..) |cookie, i| {
            if (cookie.last_access_time < oldest_time) {
                oldest_time = cookie.last_access_time;
                oldest_idx = i;
            }
        }

        var removed = self.cookies.orderedRemove(oldest_idx);
        removed.deinit();
    }
};

/// Compare cookies for Cookie header ordering.
/// Longest path first, then earliest creation time.
fn compareCookiesForHeader(_: void, a: Cookie, b: Cookie) bool {
    // Longer paths come first
    if (a.path.len != b.path.len) {
        return a.path.len > b.path.len;
    }
    // Earlier creation time comes first
    return a.creation_time < b.creation_time;
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

test "CookieStore.init and deinit" {
    const allocator = std.testing.allocator;

    var store = CookieStore.init(allocator);
    defer store.deinit();

    try std.testing.expectEqual(@as(usize, 0), store.count());
}

test "CookieStore.setCookie and getCookiesForRequest" {
    const allocator = std.testing.allocator;

    var store = CookieStore.init(allocator);
    defer store.deinit();

    try store.setCookie("session=abc123", "example.com", "/", true);

    const cookies = try store.getCookiesForRequest(
        "example.com",
        "/path",
        true,
        .same_site,
        .subresource,
    );
    defer allocator.free(cookies);

    try std.testing.expectEqual(@as(usize, 1), cookies.len);
    try std.testing.expectEqualStrings("session", cookies[0].name);
    try std.testing.expectEqualStrings("abc123", cookies[0].value);
}

test "CookieStore.setCookie updates existing" {
    const allocator = std.testing.allocator;

    var store = CookieStore.init(allocator);
    defer store.deinit();

    try store.setCookie("test=value1", "example.com", "/", true);
    try store.setCookie("test=value2", "example.com", "/", true);

    try std.testing.expectEqual(@as(usize, 1), store.count());

    const cookies = try store.getCookiesForRequest(
        "example.com",
        "/",
        true,
        .same_site,
        .subresource,
    );
    defer allocator.free(cookies);

    try std.testing.expectEqual(@as(usize, 1), cookies.len);
    try std.testing.expectEqualStrings("value2", cookies[0].value);
}

test "CookieStore secure cookie on insecure rejected" {
    const allocator = std.testing.allocator;

    var store = CookieStore.init(allocator);
    defer store.deinit();

    // Try to set Secure cookie on HTTP
    try store.setCookie("test=value; Secure", "example.com", "/", false);

    try std.testing.expectEqual(@as(usize, 0), store.count());
}

test "CookieStore path matching" {
    const allocator = std.testing.allocator;

    var store = CookieStore.init(allocator);
    defer store.deinit();

    try store.setCookie("api=token; Path=/api", "example.com", "/api", true);

    // Should match /api/v1
    const cookies1 = try store.getCookiesForRequest(
        "example.com",
        "/api/v1",
        true,
        .same_site,
        .subresource,
    );
    defer allocator.free(cookies1);
    try std.testing.expectEqual(@as(usize, 1), cookies1.len);

    // Should NOT match /other
    const cookies2 = try store.getCookiesForRequest(
        "example.com",
        "/other",
        true,
        .same_site,
        .subresource,
    );
    defer allocator.free(cookies2);
    try std.testing.expectEqual(@as(usize, 0), cookies2.len);
}

test "CookieStore domain matching" {
    const allocator = std.testing.allocator;

    var store = CookieStore.init(allocator);
    defer store.deinit();

    // Domain cookie
    try store.setCookie("test=value; Domain=example.com", "sub.example.com", "/", true);

    // Should match subdomain
    const cookies1 = try store.getCookiesForRequest(
        "other.example.com",
        "/",
        true,
        .same_site,
        .subresource,
    );
    defer allocator.free(cookies1);
    try std.testing.expectEqual(@as(usize, 1), cookies1.len);

    // Should NOT match different domain
    const cookies2 = try store.getCookiesForRequest(
        "other.com",
        "/",
        true,
        .same_site,
        .subresource,
    );
    defer allocator.free(cookies2);
    try std.testing.expectEqual(@as(usize, 0), cookies2.len);
}

test "CookieStore clear" {
    const allocator = std.testing.allocator;

    var store = CookieStore.init(allocator);
    defer store.deinit();

    try store.setCookie("a=1", "example.com", "/", true);
    try store.setCookie("b=2", "example.com", "/", true);

    try std.testing.expectEqual(@as(usize, 2), store.count());

    store.clear();

    try std.testing.expectEqual(@as(usize, 0), store.count());
}

test "CookieStore cookie ordering" {
    const allocator = std.testing.allocator;

    var store = CookieStore.init(allocator);
    defer store.deinit();

    // Set cookies with different paths
    try store.setCookie("short=1; Path=/", "example.com", "/", true);

    // Small delay to ensure different creation time
    std.Thread.sleep(1_000_000); // 1ms

    try store.setCookie("long=2; Path=/api/v1", "example.com", "/api/v1", true);

    const cookies = try store.getCookiesForRequest(
        "example.com",
        "/api/v1/resource",
        true,
        .same_site,
        .subresource,
    );
    defer allocator.free(cookies);

    // Longer path should come first
    try std.testing.expectEqual(@as(usize, 2), cookies.len);
    try std.testing.expectEqualStrings("long", cookies[0].name);
    try std.testing.expectEqualStrings("short", cookies[1].name);
}

test "CookieStore SameSite=None requires Secure" {
    const allocator = std.testing.allocator;

    var store = CookieStore.init(allocator);
    defer store.deinit();

    // SameSite=None without Secure should be rejected
    try store.setCookie("test=value; SameSite=None", "example.com", "/", true);
    try std.testing.expectEqual(@as(usize, 0), store.count());

    // SameSite=None with Secure should be accepted
    try store.setCookie("test=value; SameSite=None; Secure", "example.com", "/", true);
    try std.testing.expectEqual(@as(usize, 1), store.count());
}
