//! CORS Preflight Cache
//!
//! Spec: https://fetch.spec.whatwg.org/#cors-preflight-cache
//!
//! This module implements an in-memory CORS preflight cache to avoid
//! redundant OPTIONS requests. Cache entries expire based on the
//! Access-Control-Max-Age header.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Cache key identifying a unique preflight entry.
pub const CacheKey = struct {
    /// Serialized origin of the request
    origin: []const u8,

    /// URL being requested (without fragment)
    url: []const u8,

    /// Network partition key (for partitioned cache)
    /// For simplicity, we use the request origin.
    network_partition_key: []const u8,
};

/// CORS preflight cache entry.
pub const CacheEntry = struct {
    allocator: Allocator,

    /// Cache key components
    key: CacheKey,

    /// Allowed methods (stored uppercase)
    methods: std.StringHashMapUnmanaged(void),

    /// Allowed headers (stored byte-lowercased)
    headers: std.StringHashMapUnmanaged(void),

    /// Expiry time (absolute Unix timestamp)
    expiry_time: i64,

    /// Whether wildcard (*) was used for methods
    methods_wildcard: bool,

    /// Whether wildcard (*) was used for headers
    headers_wildcard: bool,

    /// Whether credentials are allowed
    credentials: bool,

    const Self = @This();

    /// Free all owned memory.
    pub fn deinit(self: *Self) void {
        // Free key strings
        self.allocator.free(self.key.origin);
        self.allocator.free(self.key.url);
        self.allocator.free(self.key.network_partition_key);

        // Free method strings
        var methods_iter = self.methods.keyIterator();
        while (methods_iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.methods.deinit(self.allocator);

        // Free header strings
        var headers_iter = self.headers.keyIterator();
        while (headers_iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.headers.deinit(self.allocator);
    }

    /// Check if this entry has expired.
    pub fn isExpired(self: *const Self) bool {
        return self.expiry_time < std.time.timestamp();
    }

    /// Check if a method is allowed by this cache entry.
    pub fn isMethodAllowed(self: *const Self, method: []const u8) bool {
        // Wildcard allows any method (unless credentials)
        if (self.methods_wildcard and !self.credentials) {
            return true;
        }

        // Check uppercase method
        var buf: [32]u8 = undefined;
        const upper = toUppercase(&buf, method);
        return self.methods.contains(upper);
    }

    /// Check if a header is allowed by this cache entry.
    pub fn isHeaderAllowed(self: *const Self, header: []const u8) bool {
        // Wildcard allows any header (unless credentials)
        // But Authorization always needs explicit listing
        if (self.headers_wildcard and !self.credentials) {
            if (eqlIgnoreCase(header, "Authorization")) {
                return self.headers.contains("authorization");
            }
            return true;
        }

        // Check byte-lowercased header
        var buf: [256]u8 = undefined;
        const lower = toLowercase(&buf, header);
        return self.headers.contains(lower);
    }
};

/// In-memory CORS preflight cache.
///
/// Per spec, preflight results can be cached to avoid redundant OPTIONS.
/// Cache entries expire based on Access-Control-Max-Age.
pub const PreflightCache = struct {
    allocator: Allocator,

    /// Cached entries
    entries: std.ArrayListUnmanaged(CacheEntry),

    /// Maximum age for cache entries (default 5 seconds if not specified)
    default_max_age: u64 = 5,

    /// Upper bound on max age (browsers typically cap this)
    max_max_age: u64 = 7200, // 2 hours (Chrome's default cap)

    const Self = @This();

    /// Initialize an empty cache.
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .entries = .{},
        };
    }

    /// Free all entries and the cache.
    pub fn deinit(self: *Self) void {
        for (self.entries.items) |*entry| {
            entry.deinit();
        }
        self.entries.deinit(self.allocator);
    }

    /// Match cache entry for request.
    ///
    /// Returns entry if found and not expired.
    pub fn match(
        self: *Self,
        origin: []const u8,
        url: []const u8,
        network_partition_key: []const u8,
    ) ?*CacheEntry {
        // First, clean up expired entries
        self.removeExpired();

        for (self.entries.items) |*entry| {
            if (std.mem.eql(u8, entry.key.origin, origin) and
                std.mem.eql(u8, entry.key.url, url) and
                std.mem.eql(u8, entry.key.network_partition_key, network_partition_key))
            {
                return entry;
            }
        }
        return null;
    }

    /// Create cache entry from preflight response.
    ///
    /// Parameters:
    /// - origin: Serialized origin making the request
    /// - url: URL being requested
    /// - network_partition_key: Network partition key
    /// - max_age: Max-Age from response (will be capped)
    /// - methods: Allowed methods from response
    /// - headers: Allowed headers from response
    /// - credentials: Whether credentials are allowed
    pub fn createEntry(
        self: *Self,
        origin: []const u8,
        url: []const u8,
        network_partition_key: []const u8,
        max_age: u64,
        methods: []const []const u8,
        methods_wildcard: bool,
        headers: []const []const u8,
        headers_wildcard: bool,
        credentials: bool,
    ) !void {
        // Remove existing entry for this key first
        self.clear(origin, url, network_partition_key);

        const now = std.time.timestamp();
        const capped_max_age = @min(max_age, self.max_max_age);
        const effective_max_age = if (capped_max_age == 0) self.default_max_age else capped_max_age;

        var entry = CacheEntry{
            .allocator = self.allocator,
            .key = .{
                .origin = try self.allocator.dupe(u8, origin),
                .url = try self.allocator.dupe(u8, url),
                .network_partition_key = try self.allocator.dupe(u8, network_partition_key),
            },
            .methods = .{},
            .headers = .{},
            .expiry_time = now + @as(i64, @intCast(effective_max_age)),
            .methods_wildcard = methods_wildcard,
            .headers_wildcard = headers_wildcard,
            .credentials = credentials,
        };
        errdefer entry.deinit();

        // Store methods (uppercase)
        for (methods) |method| {
            var buf: [32]u8 = undefined;
            const upper = toUppercase(&buf, method);
            const owned = try self.allocator.dupe(u8, upper);
            errdefer self.allocator.free(owned);
            try entry.methods.put(self.allocator, owned, {});
        }

        // Store headers (byte-lowercased)
        for (headers) |header| {
            var buf: [256]u8 = undefined;
            const lower = toLowercase(&buf, header);
            const owned = try self.allocator.dupe(u8, lower);
            errdefer self.allocator.free(owned);
            try entry.headers.put(self.allocator, owned, {});
        }

        try self.entries.append(self.allocator, entry);
    }

    /// Clear cache entry for origin/URL.
    pub fn clear(
        self: *Self,
        origin: []const u8,
        url: []const u8,
        network_partition_key: []const u8,
    ) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            const entry = &self.entries.items[i];
            if (std.mem.eql(u8, entry.key.origin, origin) and
                std.mem.eql(u8, entry.key.url, url) and
                std.mem.eql(u8, entry.key.network_partition_key, network_partition_key))
            {
                var removed = self.entries.orderedRemove(i);
                removed.deinit();
            } else {
                i += 1;
            }
        }
    }

    /// Remove all expired entries.
    pub fn removeExpired(self: *Self) void {
        const now = std.time.timestamp();
        var i: usize = 0;
        while (i < self.entries.items.len) {
            if (self.entries.items[i].expiry_time < now) {
                var removed = self.entries.orderedRemove(i);
                removed.deinit();
            } else {
                i += 1;
            }
        }
    }

    /// Clear entire cache.
    pub fn clearAll(self: *Self) void {
        for (self.entries.items) |*entry| {
            entry.deinit();
        }
        self.entries.clearRetainingCapacity();
    }

    /// Get the number of entries in the cache.
    pub fn count(self: *const Self) usize {
        return self.entries.items.len;
    }
};

/// Convert string to uppercase (for method comparison).
fn toUppercase(buf: []u8, str: []const u8) []const u8 {
    const len = @min(str.len, buf.len);
    for (str[0..len], 0..) |c, i| {
        buf[i] = std.ascii.toUpper(c);
    }
    return buf[0..len];
}

/// Convert string to lowercase (for header comparison).
fn toLowercase(buf: []u8, str: []const u8) []const u8 {
    const len = @min(str.len, buf.len);
    for (str[0..len], 0..) |c, i| {
        buf[i] = std.ascii.toLower(c);
    }
    return buf[0..len];
}

/// Case-insensitive string comparison.
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

test "PreflightCache.init and deinit" {
    const allocator = std.testing.allocator;

    var cache = PreflightCache.init(allocator);
    defer cache.deinit();

    try std.testing.expectEqual(@as(usize, 0), cache.count());
}

test "PreflightCache.createEntry and match" {
    const allocator = std.testing.allocator;

    var cache = PreflightCache.init(allocator);
    defer cache.deinit();

    const methods = [_][]const u8{ "GET", "PUT", "DELETE" };
    const headers = [_][]const u8{ "X-Custom", "Content-Type" };

    try cache.createEntry(
        "https://example.com",
        "https://api.example.com/data",
        "https://example.com",
        3600,
        &methods,
        false,
        &headers,
        false,
        false,
    );

    try std.testing.expectEqual(@as(usize, 1), cache.count());

    // Match should find the entry
    const entry = cache.match(
        "https://example.com",
        "https://api.example.com/data",
        "https://example.com",
    );
    try std.testing.expect(entry != null);

    // Non-matching should return null
    const no_match = cache.match(
        "https://other.com",
        "https://api.example.com/data",
        "https://other.com",
    );
    try std.testing.expect(no_match == null);
}

test "CacheEntry.isMethodAllowed" {
    const allocator = std.testing.allocator;

    var cache = PreflightCache.init(allocator);
    defer cache.deinit();

    const methods = [_][]const u8{ "PUT", "DELETE" };
    const headers = [_][]const u8{};

    try cache.createEntry(
        "https://example.com",
        "https://api.example.com/data",
        "https://example.com",
        3600,
        &methods,
        false,
        &headers,
        false,
        false,
    );

    const entry = cache.match(
        "https://example.com",
        "https://api.example.com/data",
        "https://example.com",
    ).?;

    try std.testing.expect(entry.isMethodAllowed("PUT"));
    try std.testing.expect(entry.isMethodAllowed("put")); // case insensitive
    try std.testing.expect(entry.isMethodAllowed("DELETE"));
    try std.testing.expect(!entry.isMethodAllowed("PATCH"));
}

test "CacheEntry.isMethodAllowed with wildcard" {
    const allocator = std.testing.allocator;

    var cache = PreflightCache.init(allocator);
    defer cache.deinit();

    const methods = [_][]const u8{"*"};
    const headers = [_][]const u8{};

    try cache.createEntry(
        "https://example.com",
        "https://api.example.com/data",
        "https://example.com",
        3600,
        &methods,
        true, // wildcard
        &headers,
        false,
        false,
    );

    const entry = cache.match(
        "https://example.com",
        "https://api.example.com/data",
        "https://example.com",
    ).?;

    // Wildcard allows any method
    try std.testing.expect(entry.isMethodAllowed("ANY"));
    try std.testing.expect(entry.isMethodAllowed("CUSTOM"));
}

test "CacheEntry.isHeaderAllowed" {
    const allocator = std.testing.allocator;

    var cache = PreflightCache.init(allocator);
    defer cache.deinit();

    const methods = [_][]const u8{};
    const headers = [_][]const u8{ "X-Custom", "Content-Type" };

    try cache.createEntry(
        "https://example.com",
        "https://api.example.com/data",
        "https://example.com",
        3600,
        &methods,
        false,
        &headers,
        false,
        false,
    );

    const entry = cache.match(
        "https://example.com",
        "https://api.example.com/data",
        "https://example.com",
    ).?;

    try std.testing.expect(entry.isHeaderAllowed("X-Custom"));
    try std.testing.expect(entry.isHeaderAllowed("x-custom")); // case insensitive
    try std.testing.expect(entry.isHeaderAllowed("Content-Type"));
    try std.testing.expect(!entry.isHeaderAllowed("Authorization"));
}

test "CacheEntry.isHeaderAllowed with wildcard" {
    const allocator = std.testing.allocator;

    var cache = PreflightCache.init(allocator);
    defer cache.deinit();

    const methods = [_][]const u8{};
    const headers = [_][]const u8{"*"};

    try cache.createEntry(
        "https://example.com",
        "https://api.example.com/data",
        "https://example.com",
        3600,
        &methods,
        false,
        &headers,
        true, // wildcard
        false,
    );

    const entry = cache.match(
        "https://example.com",
        "https://api.example.com/data",
        "https://example.com",
    ).?;

    // Wildcard allows any header except Authorization
    try std.testing.expect(entry.isHeaderAllowed("X-Any-Header"));
    try std.testing.expect(!entry.isHeaderAllowed("Authorization")); // Needs explicit listing
}

test "PreflightCache.clear" {
    const allocator = std.testing.allocator;

    var cache = PreflightCache.init(allocator);
    defer cache.deinit();

    const methods = [_][]const u8{};
    const headers = [_][]const u8{};

    try cache.createEntry(
        "https://example.com",
        "https://api.example.com/data",
        "https://example.com",
        3600,
        &methods,
        false,
        &headers,
        false,
        false,
    );

    try std.testing.expectEqual(@as(usize, 1), cache.count());

    cache.clear(
        "https://example.com",
        "https://api.example.com/data",
        "https://example.com",
    );

    try std.testing.expectEqual(@as(usize, 0), cache.count());
}

test "PreflightCache.clearAll" {
    const allocator = std.testing.allocator;

    var cache = PreflightCache.init(allocator);
    defer cache.deinit();

    const methods = [_][]const u8{};
    const headers = [_][]const u8{};

    try cache.createEntry("https://a.com", "https://api.a.com/", "https://a.com", 3600, &methods, false, &headers, false, false);
    try cache.createEntry("https://b.com", "https://api.b.com/", "https://b.com", 3600, &methods, false, &headers, false, false);

    try std.testing.expectEqual(@as(usize, 2), cache.count());

    cache.clearAll();

    try std.testing.expectEqual(@as(usize, 0), cache.count());
}

test "PreflightCache max age capping" {
    const allocator = std.testing.allocator;

    var cache = PreflightCache.init(allocator);
    cache.max_max_age = 100; // Cap at 100 seconds
    defer cache.deinit();

    const methods = [_][]const u8{};
    const headers = [_][]const u8{};

    // Try to create with 1000 second max age
    try cache.createEntry(
        "https://example.com",
        "https://api.example.com/data",
        "https://example.com",
        1000, // This should be capped to 100
        &methods,
        false,
        &headers,
        false,
        false,
    );

    const entry = cache.match(
        "https://example.com",
        "https://api.example.com/data",
        "https://example.com",
    ).?;

    // Expiry should be roughly now + 100 seconds, not now + 1000
    const now = std.time.timestamp();
    try std.testing.expect(entry.expiry_time <= now + 101);
}

test "PreflightCache credentials with wildcard" {
    const allocator = std.testing.allocator;

    var cache = PreflightCache.init(allocator);
    defer cache.deinit();

    const methods = [_][]const u8{"*"};
    const headers = [_][]const u8{"*"};

    try cache.createEntry(
        "https://example.com",
        "https://api.example.com/data",
        "https://example.com",
        3600,
        &methods,
        true,
        &headers,
        true,
        true, // credentials enabled
    );

    const entry = cache.match(
        "https://example.com",
        "https://api.example.com/data",
        "https://example.com",
    ).?;

    // With credentials, wildcard doesn't work
    try std.testing.expect(!entry.isMethodAllowed("CUSTOM"));
    try std.testing.expect(!entry.isHeaderAllowed("X-Custom"));
}
