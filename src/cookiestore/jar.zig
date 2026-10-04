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
const clock = @import("clock");
const ChangeType = @import("change_observer.zig").ChangeType;

/// Who hears about the store's cookie changes (Cookie Store "process cookie
/// changes"): a cookie inserted or replaced is `changed`, one removed -
/// expired, evicted, or replaced by an expired one - is `deleted`. The
/// cookie is borrowed for the call.
pub const ChangeHook = struct {
    callback: *const fn (context: ?*anyopaque, change_type: ChangeType, cookie: *const Cookie) void,
    context: ?*anyopaque = null,
};

/// Maximum cookies per domain (per RFC 6265bis recommendations)
pub const MAX_COOKIES_PER_DOMAIN: usize = 50;

/// Maximum total cookies in the jar
pub const MAX_TOTAL_COOKIES: usize = 3000;

/// The same-site mode a retrieval runs in (layered cookies "Retrieve
/// Cookies" sameSite; Fetch "determine the same-site mode"): which
/// SameSite cookies it may return.
pub const SameSiteMode = enum {
    /// Every cookie: Strict, Lax, unset and None.
    strict_or_less,
    /// All but SameSite=Strict.
    lax_or_less,
    /// Neither Strict nor Lax: unset and None.
    unset_or_less,
    /// SameSite=None only.
    none,
};

/// Options for retrieving cookies
pub const RetrieveOptions = struct {
    /// The request URL's host
    host: []const u8,
    /// The request URL's path
    path: []const u8 = "/",
    /// httpOnlyAllowed: an HTTP request, not a "non-HTTP" API such as
    /// document.cookie - only it sees HttpOnly cookies.
    is_http: bool = false,
    /// isSecure: the request URL's scheme is secure (https, wss).
    is_secure: bool = false,
    /// The same-site mode of the retrieval.
    same_site: SameSiteMode = .strict_or_less,
    /// Partition key for CHIPS (null for unpartitioned access)
    partition_key: ?PartitionKey = null,
    /// Filter by cookie name (null for all)
    name: ?[]const u8 = null,
};

/// Cookie Jar - manages a collection of cookies
///
/// One jar serves every thread of a Browser - its window agent's and each
/// worker's (docs/instances.md): a worker's fetch stores and retrieves cookies
/// on the worker's thread. Whoever reaches it while another thread can - the
/// entry points in http_integration.zig and algorithms.zig - holds `lock()`
/// across its whole check-and-store or retrieve, and every read of `cookies`
/// outside this file is under it. The methods themselves do not lock (they
/// are what the lock holder calls); a single-threaded caller (a unit test)
/// may call them unlocked.
pub const CookieJar = struct {
    /// All cookies stored by a composite key
    cookies: std.ArrayListUnmanaged(Cookie),

    /// Allocator for the jar
    allocator: std.mem.Allocator,

    /// Told of every change (see `ChangeHook`); null for none.
    on_change: ?ChangeHook = null,

    /// Protects `cookies`, `pending` and `held` (and so every method here)
    /// for whoever holds it through `lock`/`unlock`; never held across a
    /// change hook - those wait in `pending` until `unlock`.
    mutex: std.Io.Mutex = .init,

    /// Whether the jar is locked: a change raised meanwhile waits in
    /// `pending` for `unlock`, so a hook that reaches the jar again cannot
    /// deadlock on it.
    held: bool = false,

    /// Changes raised while locked: each cookie OWNED (a clone), handed to
    /// the hook by `unlock` after releasing the lock.
    pending: std.ArrayListUnmanaged(PendingChange) = .empty,

    const PendingChange = struct {
        change_type: ChangeType,
        cookie: Cookie,
    };

    const Self = @This();

    /// Create a new cookie jar
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .cookies = .empty,
            .allocator = allocator,
        };
    }

    /// Take the jar for a check-and-store or a retrieve that other threads
    /// must not interleave with. Not re-entrant.
    pub fn lock(self: *Self) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        self.held = true;
    }

    /// Release the jar, then tell the change hook what changed while it was
    /// held - outside the lock, each cookie borrowed for its call.
    pub fn unlock(self: *Self) void {
        var pending = self.pending;
        self.pending = .empty;
        self.held = false;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        defer pending.deinit(self.allocator);
        for (pending.items) |*change| {
            defer change.cookie.deinit();
            if (self.on_change) |hook| hook.callback(hook.context, change.change_type, &change.cookie);
        }
    }

    fn notify(self: *Self, change_type: ChangeType, cookie: *const Cookie) void {
        const hook = self.on_change orelse return;
        if (!self.held) return hook.callback(hook.context, change_type, cookie);
        // Locked: the hook hears it at `unlock`, about a copy - the cookie
        // may be gone from the store by then. Out of memory, it hears nothing.
        var copy = cookie.clone(self.allocator) catch return;
        self.pending.append(self.allocator, .{ .change_type = change_type, .cookie = copy }) catch copy.deinit();
    }

    /// Free all resources
    pub fn deinit(self: *Self) void {
        for (self.cookies.items) |*cookie| {
            cookie.deinit();
        }
        self.cookies.deinit(self.allocator);
        for (self.pending.items) |*change| change.cookie.deinit();
        self.pending.deinit(self.allocator);
    }

    /// Store a cookie, replacing any existing cookie with the same identity
    /// (and keeping its creation-time), then garbage collect the cookie's
    /// host - which drops the cookie at once if it has already expired, so
    /// storing an expired cookie deletes the one it replaces.
    ///
    /// No policy is applied: layered cookies "Store a Cookie"
    /// (http_integration.storeCookie) decides whether a cookie may be stored
    /// and calls this.
    pub fn store(self: *Self, cookie: Cookie) !void {
        const old = self.findIdentity(cookie);
        if (cookie.isExpired()) {
            // Inserted and at once collected: the change is the old
            // cookie's removal, if there was one.
            if (old) |index| {
                self.removeAt(index);
                self.notify(.deleted, &cookie);
            }
        } else {
            var owned_cookie = try cookie.clone(self.allocator);
            errdefer owned_cookie.deinit();
            if (old) |index| {
                owned_cookie.creation_time = self.cookies.items[index].creation_time;
                self.removeAt(index);
            }
            try self.cookies.append(self.allocator, owned_cookie);
            self.notify(.changed, &self.cookies.items[self.cookies.items.len - 1]);
        }
        self.garbageCollect(cookie.domain orelse "");
    }

    /// The index of the cookie with `cookie`'s identity - its name, host
    /// (host-equal), host-only flag, path and partition key - if any.
    pub fn findIdentity(self: *const Self, cookie: Cookie) ?usize {
        for (self.cookies.items, 0..) |existing, index| {
            if (existing.hasSameIdentity(cookie)) return index;
        }
        return null;
    }

    /// Remove and free the cookie at `index`.
    pub fn removeAt(self: *Self, index: usize) void {
        var removed = self.cookies.orderedRemove(index);
        removed.deinit();
    }

    /// Remove the cookie at `index` from the store - expired or evicted -
    /// telling the change hook it is `deleted`.
    fn collectAt(self: *Self, index: usize) void {
        var removed = self.cookies.orderedRemove(index);
        defer removed.deinit();
        self.notify(.deleted, &removed);
    }

    /// Retrieve cookies matching the given options
    /// (layered cookies "Retrieve Cookies"), sorted, their last-access-time
    /// updated. The list and its cookies are the caller's.
    pub fn retrieve(self: *Self, options: RetrieveOptions) !std.ArrayListUnmanaged(Cookie) {
        var result: std.ArrayListUnmanaged(Cookie) = .empty;
        errdefer {
            for (result.items) |*c| c.deinit();
            result.deinit(self.allocator);
        }

        // An expired cookie is no longer in the store.
        self.removeExpired();

        // 2. The cookies that meet the conditions.
        for (self.cookies.items) |*cookie| {
            if (cookieMatches(cookie, options)) {
                // 4. Set the last-access-time of each cookie to now.
                cookie.touch();
                const cloned = try cookie.clone(self.allocator);
                try result.append(self.allocator, cloned);
            }
        }

        // 3. Sort them.
        sortCookies(result.items);

        return result;
    }

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
                self.removeAt(i);
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

    /// Remove all expired cookies (layered cookies "Remove Expired Cookies").
    pub fn removeExpired(self: *Self) void {
        var i: usize = 0;
        while (i < self.cookies.items.len) {
            if (self.cookies.items[i].isExpired()) {
                self.collectAt(i);
            } else {
                i += 1;
            }
        }
    }

    /// Layered cookies "Garbage Collect Cookies" given `host`: the expired
    /// cookies, then the host's excess, then the store's.
    pub fn garbageCollect(self: *Self, host: []const u8) void {
        self.removeExpired();
        self.removeExcessForHost(host);
        self.removeGlobalExcess();
    }

    /// Whether `cookie` matches the retrieve options (layered cookies
    /// "Retrieve Cookies" step 2) - also what makes a change observable for
    /// a URL (Cookie Store "observable changes").
    pub fn cookieMatches(cookie: *const Cookie, options: RetrieveOptions) bool {
        // Name filter
        if (options.name) |name| {
            if (!std.mem.eql(u8, cookie.name, name)) {
                return false;
            }
        }

        // A host-only cookie's host is host-equal to host; any other's is
        // one host Domain-Matches.
        const domain = cookie.domain orelse return false;
        if (cookie.host_only) {
            if (!std.ascii.eqlIgnoreCase(options.host, domain)) return false;
        } else {
            if (!domain_matching.domainMatches(options.host, domain)) return false;
        }

        // path Path-Matches cookie's path.
        if (!domain_matching.pathMatches(options.path, cookie.path)) {
            return false;
        }

        // A secure cookie goes only where isSecure.
        if (cookie.secure and !options.is_secure) {
            return false;
        }

        // An HttpOnly cookie only where httpOnlyAllowed.
        if (cookie.http_only and !options.is_http) {
            return false;
        }

        // SameSite: strict for "strict-or-less", lax for that or
        // "lax-or-less", unset for those or "unset-or-less", none always.
        const allowed = switch (cookie.same_site) {
            .strict => options.same_site == .strict_or_less,
            .lax => options.same_site == .strict_or_less or options.same_site == .lax_or_less,
            .unset => options.same_site != .none,
            .none => true,
        };
        if (!allowed) return false;

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

    /// "Retrieve Cookies" step 3: cookies whose path's size is greater
    /// first, then earlier creation-time first. A path's size is its
    /// number of segments - its "/"s, serialized.
    fn sortCookies(cookies: []Cookie) void {
        std.mem.sort(Cookie, cookies, {}, struct {
            fn lessThan(_: void, a: Cookie, b: Cookie) bool {
                const a_size = std.mem.count(u8, a.path, "/");
                const b_size = std.mem.count(u8, b.path, "/");
                if (a_size != b_size) return a_size > b_size;
                return a.creation_time < b.creation_time;
            }
        }.lessThan);
    }

    /// Layered cookies "Remove Excess Cookies for a Host": while the host
    /// has more than the per-host limit, drop its least recently accessed
    /// cookie - a non-secure one while there is one.
    fn removeExcessForHost(self: *Self, host: []const u8) void {
        while (true) {
            var host_count: usize = 0;
            var victim: ?usize = null;
            var victim_secure = true;
            var victim_time: i64 = std.math.maxInt(i64);
            for (self.cookies.items, 0..) |cookie, index| {
                const domain = cookie.domain orelse continue;
                if (!std.ascii.eqlIgnoreCase(domain, host)) continue;
                host_count += 1;
                // Insecure before secure; within each, earliest access.
                const better = if (cookie.secure != victim_secure)
                    !cookie.secure
                else
                    cookie.last_access_time < victim_time;
                if (victim == null or better) {
                    victim = index;
                    victim_secure = cookie.secure;
                    victim_time = cookie.last_access_time;
                }
            }
            if (host_count <= MAX_COOKIES_PER_DOMAIN) return;
            self.collectAt(victim.?);
        }
    }

    /// Layered cookies "Remove Global Excess Cookies": while the store has
    /// more than its limit, drop the least recently accessed cookie.
    fn removeGlobalExcess(self: *Self) void {
        while (self.cookies.items.len > MAX_TOTAL_COOKIES) {
            var oldest: usize = 0;
            for (self.cookies.items, 0..) |cookie, index| {
                if (cookie.last_access_time < self.cookies.items[oldest].last_access_time) oldest = index;
            }
            self.collectAt(oldest);
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
        .same_site = .strict_or_less,
    });
    defer {
        for (same_site.items) |*c| c.deinit();
        same_site.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 2), same_site.items.len);

    // "lax-or-less" should only get lax
    var cross_safe = try jar.retrieve(.{
        .host = "example.com",
        .is_http = true,
        .same_site = .lax_or_less,
    });
    defer {
        for (cross_safe.items) |*c| c.deinit();
        cross_safe.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 1), cross_safe.items.len);
    try std.testing.expectEqualStrings("lax", cross_safe.items[0].name);

    // "unset-or-less" should get neither
    var cross_unsafe = try jar.retrieve(.{
        .host = "example.com",
        .is_http = true,
        .same_site = .unset_or_less,
    });
    defer {
        for (cross_unsafe.items) |*c| c.deinit();
        cross_unsafe.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 0), cross_unsafe.items.len);

    // A cookie with no SameSite ("unset") goes in "unset-or-less" too, and
    // a SameSite=None one in every mode.
    var unset_cookie = try Cookie.init(allocator, "unset", "3");
    defer unset_cookie.deinit();
    try unset_cookie.setDomain("example.com");
    unset_cookie.same_site = .unset;
    try jar.store(unset_cookie);
    var none_cookie = try Cookie.init(allocator, "none", "4");
    defer none_cookie.deinit();
    try none_cookie.setDomain("example.com");
    none_cookie.same_site = .none;
    none_cookie.secure = true;
    try jar.store(none_cookie);
    const Case = struct { mode: SameSiteMode, count: usize };
    for ([_]Case{ .{ .mode = .strict_or_less, .count = 4 }, .{ .mode = .lax_or_less, .count = 3 }, .{ .mode = .unset_or_less, .count = 2 }, .{ .mode = .none, .count = 1 } }) |case| {
        var got = try jar.retrieve(.{ .host = "example.com", .is_http = true, .is_secure = true, .same_site = case.mode });
        defer {
            for (got.items) |*c| c.deinit();
            got.deinit(allocator);
        }
        try std.testing.expectEqual(case.count, got.items.len);
    }
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
    expired.expiry_time = clock.wallMillis() - 1000; // In the past
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

const HookLog = struct {
    changed: usize = 0,
    deleted: usize = 0,
    last_name: [16]u8 = undefined,
    last_len: usize = 0,

    fn record(context: ?*anyopaque, change_type: ChangeType, cookie: *const Cookie) void {
        const self: *HookLog = @ptrCast(@alignCast(context.?));
        switch (change_type) {
            .changed => self.changed += 1,
            .deleted => self.deleted += 1,
        }
        self.last_len = @min(cookie.name.len, self.last_name.len);
        @memcpy(self.last_name[0..self.last_len], cookie.name[0..self.last_len]);
    }
};

test "CookieJar - the change hook hears inserts, replacements and removals, once each" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    var log: HookLog = .{};
    jar.on_change = .{ .callback = &HookLog.record, .context = &log };

    var cookie = try Cookie.init(allocator, "a", "1");
    defer cookie.deinit();
    try cookie.setDomain("example.com");
    try jar.store(cookie);
    try std.testing.expectEqual(@as(usize, 1), log.changed);

    // A replacement is one `changed`, never a delete plus an add.
    try jar.store(cookie);
    try std.testing.expectEqual(@as(usize, 2), log.changed);
    try std.testing.expectEqual(@as(usize, 0), log.deleted);

    // An expired cookie replacing it is its deletion.
    cookie.expiry_time = 0;
    try jar.store(cookie);
    try std.testing.expectEqual(@as(usize, 1), log.deleted);
    try std.testing.expectEqualStrings("a", log.last_name[0..log.last_len]);
    try std.testing.expectEqual(@as(usize, 0), jar.count());

    // An expired cookie with nothing to replace changes nothing.
    try jar.store(cookie);
    try std.testing.expectEqual(@as(usize, 1), log.deleted);
    try std.testing.expectEqual(@as(usize, 2), log.changed);

    // One that expires in the store is deleted when the store collects it.
    cookie.expiry_time = null;
    try jar.store(cookie);
    jar.cookies.items[0].expiry_time = 1;
    jar.removeExpired();
    try std.testing.expectEqual(@as(usize, 2), log.deleted);
}
