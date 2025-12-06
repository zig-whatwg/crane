//! Cookie Store API - Core Cookie Types
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//! RFC 6265bis: https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
//!
//! This module implements the core Cookie data structure and associated types
//! used throughout the CookieStore API implementation.

const std = @import("std");

/// SameSite attribute values per CookieSameSite enum
/// https://cookiestore.spec.whatwg.org/#enumdef-cookiesamesite
pub const SameSite = enum {
    /// Cookie is only sent in first-party context
    strict,
    /// Cookie is sent with top-level navigations and GET requests from third-party sites
    lax,
    /// Cookie is sent in all contexts (requires Secure attribute)
    none,

    /// Convert to string representation
    pub fn toString(self: SameSite) []const u8 {
        return switch (self) {
            .strict => "strict",
            .lax => "lax",
            .none => "none",
        };
    }

    /// Parse from string (case-insensitive)
    pub fn fromString(s: []const u8) ?SameSite {
        if (std.ascii.eqlIgnoreCase(s, "strict")) return .strict;
        if (std.ascii.eqlIgnoreCase(s, "lax")) return .lax;
        if (std.ascii.eqlIgnoreCase(s, "none")) return .none;
        return null;
    }
};

/// Partition key for CHIPS (Cookies Having Independent Partitioned State)
/// https://developer.mozilla.org/en-US/docs/Web/Privacy/Privacy_sandbox/Partitioned_cookies
pub const PartitionKey = struct {
    /// Top-level site origin (scheme + eTLD+1)
    top_level_site: []const u8,

    /// Allocator used (null if borrowed)
    allocator: ?std.mem.Allocator = null,

    const Self = @This();

    /// Create a partition key with owned memory
    pub fn init(allocator: std.mem.Allocator, top_level_site: []const u8) !Self {
        return Self{
            .top_level_site = try allocator.dupe(u8, top_level_site),
            .allocator = allocator,
        };
    }

    /// Create a partition key without copying (for temporary use)
    pub fn initBorrowed(top_level_site: []const u8) Self {
        return Self{
            .top_level_site = top_level_site,
            .allocator = null,
        };
    }

    /// Free the partition key's resources
    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            alloc.free(self.top_level_site);
        }
        self.* = undefined;
    }

    /// Clone the partition key
    pub fn clone(self: Self, allocator: std.mem.Allocator) !Self {
        return Self{
            .top_level_site = try allocator.dupe(u8, self.top_level_site),
            .allocator = allocator,
        };
    }

    /// Check equality
    pub fn eql(self: Self, other: Self) bool {
        return std.mem.eql(u8, self.top_level_site, other.top_level_site);
    }
};

/// Core Cookie structure per RFC 6265bis
/// https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
pub const Cookie = struct {
    /// Cookie name (UTF-8 encoded bytes)
    name: []const u8,

    /// Cookie value (UTF-8 encoded bytes)
    value: []const u8,

    /// Domain attribute (lowercase, without leading dot)
    /// null means host-only cookie
    domain: ?[]const u8 = null,

    /// Path attribute (must start with "/")
    path: []const u8 = "/",

    /// Expiration time as Unix timestamp in milliseconds
    /// null means session cookie (expires when session ends)
    expiry_time: ?i64 = null,

    /// Creation time as Unix timestamp in milliseconds
    creation_time: i64,

    /// Last access time as Unix timestamp in milliseconds
    last_access_time: i64,

    /// Secure attribute - cookie only sent over HTTPS
    secure: bool = false,

    /// HttpOnly attribute - cookie not accessible via JavaScript
    http_only: bool = false,

    /// SameSite attribute
    same_site: SameSite = .lax,

    /// Whether this is a host-only cookie (no Domain attribute was specified)
    host_only: bool = true,

    /// Partition key for CHIPS (null if not partitioned)
    partition_key: ?PartitionKey = null,

    /// Allocator used for owned memory
    allocator: ?std.mem.Allocator = null,

    const Self = @This();

    /// Create a new cookie with owned memory
    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        value: []const u8,
    ) !Self {
        const now = std.time.milliTimestamp();
        return Self{
            .name = try allocator.dupe(u8, name),
            .value = try allocator.dupe(u8, value),
            .creation_time = now,
            .last_access_time = now,
            .allocator = allocator,
        };
    }

    /// Free the cookie's resources
    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            alloc.free(self.name);
            alloc.free(self.value);
            if (self.domain) |d| alloc.free(d);
            if (!std.mem.eql(u8, self.path, "/")) {
                // Only free if not the default static string
                alloc.free(self.path);
            }
            if (self.partition_key) |*pk| {
                if (pk.allocator != null) {
                    pk.deinit();
                }
            }
        }
        self.* = undefined;
    }

    /// Clone the cookie
    pub fn clone(self: Self, allocator: std.mem.Allocator) !Self {
        const cookie = Self{
            .name = try allocator.dupe(u8, self.name),
            .value = try allocator.dupe(u8, self.value),
            .domain = if (self.domain) |d| try allocator.dupe(u8, d) else null,
            .path = if (std.mem.eql(u8, self.path, "/")) "/" else try allocator.dupe(u8, self.path),
            .expiry_time = self.expiry_time,
            .creation_time = self.creation_time,
            .last_access_time = self.last_access_time,
            .secure = self.secure,
            .http_only = self.http_only,
            .same_site = self.same_site,
            .host_only = self.host_only,
            .partition_key = if (self.partition_key) |pk| try pk.clone(allocator) else null,
            .allocator = allocator,
        };
        return cookie;
    }

    /// Set the domain attribute
    pub fn setDomain(self: *Self, domain: []const u8) !void {
        if (self.allocator) |alloc| {
            if (self.domain) |d| alloc.free(d);
            self.domain = try alloc.dupe(u8, domain);
            self.host_only = false;
        }
    }

    /// Set the path attribute
    pub fn setPath(self: *Self, path: []const u8) !void {
        if (self.allocator) |alloc| {
            if (!std.mem.eql(u8, self.path, "/")) {
                alloc.free(self.path);
            }
            self.path = try alloc.dupe(u8, path);
        }
    }

    /// Set the partition key
    pub fn setPartitionKey(self: *Self, partition_key: PartitionKey) !void {
        if (self.allocator) |alloc| {
            if (self.partition_key) |*pk| {
                if (pk.allocator != null) {
                    pk.deinit();
                }
            }
            self.partition_key = try partition_key.clone(alloc);
        }
    }

    /// Check if the cookie has expired
    pub fn isExpired(self: Self) bool {
        if (self.expiry_time) |expiry| {
            return std.time.milliTimestamp() > expiry;
        }
        return false; // Session cookies never expire based on time
    }

    /// Check if the cookie is a session cookie
    pub fn isSession(self: Self) bool {
        return self.expiry_time == null;
    }

    /// Check if the cookie is partitioned
    pub fn isPartitioned(self: Self) bool {
        return self.partition_key != null;
    }

    /// Update the last access time to now
    pub fn touch(self: *Self) void {
        self.last_access_time = std.time.milliTimestamp();
    }

    /// Check if two cookies have the same identity (name, domain, path, partition key)
    /// Used for determining if a new cookie should replace an existing one
    pub fn hasSameIdentity(self: Self, other: Self) bool {
        // Name must match
        if (!std.mem.eql(u8, self.name, other.name)) return false;

        // Domain must match (considering null)
        const domain_match = if (self.domain) |d1|
            if (other.domain) |d2| std.mem.eql(u8, d1, d2) else false
        else
            other.domain == null;
        if (!domain_match) return false;

        // Path must match
        if (!std.mem.eql(u8, self.path, other.path)) return false;

        // Partition key must match
        const pk_match = if (self.partition_key) |pk1|
            if (other.partition_key) |pk2| pk1.eql(pk2) else false
        else
            other.partition_key == null;

        return pk_match;
    }

    /// Get effective domain (domain if set, otherwise the host)
    pub fn getEffectiveDomain(self: Self, request_host: []const u8) []const u8 {
        return self.domain orelse request_host;
    }
};

/// CookieListItem dictionary for WebIDL interface
/// https://cookiestore.spec.whatwg.org/#dictdef-cookielistitem
pub const CookieListItem = struct {
    /// Cookie name (USVString)
    name: []const u8,

    /// Cookie value (USVString)
    value: []const u8,

    /// Allocator used for owned memory
    allocator: ?std.mem.Allocator = null,

    const Self = @This();

    /// Create from a Cookie
    pub fn fromCookie(allocator: std.mem.Allocator, cookie: Cookie) !Self {
        return Self{
            .name = try allocator.dupe(u8, cookie.name),
            .value = try allocator.dupe(u8, cookie.value),
            .allocator = allocator,
        };
    }

    /// Create with owned memory
    pub fn init(allocator: std.mem.Allocator, name: []const u8, value: []const u8) !Self {
        return Self{
            .name = try allocator.dupe(u8, name),
            .value = try allocator.dupe(u8, value),
            .allocator = allocator,
        };
    }

    /// Create without copying (for temporary use)
    pub fn initBorrowed(name: []const u8, value: []const u8) Self {
        return Self{
            .name = name,
            .value = value,
            .allocator = null,
        };
    }

    /// Free resources
    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            alloc.free(self.name);
            alloc.free(self.value);
        }
        self.* = undefined;
    }

    /// Clone the item
    pub fn clone(self: Self, allocator: std.mem.Allocator) !Self {
        return Self{
            .name = try allocator.dupe(u8, self.name),
            .value = try allocator.dupe(u8, self.value),
            .allocator = allocator,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "SameSite - toString and fromString" {
    try std.testing.expectEqualStrings("strict", SameSite.strict.toString());
    try std.testing.expectEqualStrings("lax", SameSite.lax.toString());
    try std.testing.expectEqualStrings("none", SameSite.none.toString());

    try std.testing.expectEqual(SameSite.strict, SameSite.fromString("strict").?);
    try std.testing.expectEqual(SameSite.lax, SameSite.fromString("Lax").?);
    try std.testing.expectEqual(SameSite.none, SameSite.fromString("NONE").?);
    try std.testing.expect(SameSite.fromString("invalid") == null);
}

test "PartitionKey - init and clone" {
    const allocator = std.testing.allocator;

    var pk1 = try PartitionKey.init(allocator, "https://example.com");
    defer pk1.deinit();

    var pk2 = try pk1.clone(allocator);
    defer pk2.deinit();

    try std.testing.expect(pk1.eql(pk2));
    try std.testing.expectEqualStrings("https://example.com", pk1.top_level_site);
}

test "Cookie - init and basic properties" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "session_id", "abc123");
    defer cookie.deinit();

    try std.testing.expectEqualStrings("session_id", cookie.name);
    try std.testing.expectEqualStrings("abc123", cookie.value);
    try std.testing.expectEqualStrings("/", cookie.path);
    try std.testing.expect(cookie.domain == null);
    try std.testing.expect(cookie.host_only);
    try std.testing.expect(!cookie.secure);
    try std.testing.expect(!cookie.http_only);
    try std.testing.expect(cookie.isSession());
    try std.testing.expect(!cookie.isExpired());
    try std.testing.expect(!cookie.isPartitioned());
}

test "Cookie - clone" {
    const allocator = std.testing.allocator;

    var cookie1 = try Cookie.init(allocator, "test", "value");
    cookie1.secure = true;
    cookie1.same_site = .strict;
    try cookie1.setDomain("example.com");
    defer cookie1.deinit();

    var cookie2 = try cookie1.clone(allocator);
    defer cookie2.deinit();

    try std.testing.expectEqualStrings(cookie1.name, cookie2.name);
    try std.testing.expectEqualStrings(cookie1.value, cookie2.value);
    try std.testing.expectEqualStrings(cookie1.domain.?, cookie2.domain.?);
    try std.testing.expect(cookie2.secure);
    try std.testing.expectEqual(SameSite.strict, cookie2.same_site);
}

test "Cookie - expiration" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "test", "value");
    defer cookie.deinit();

    // Session cookie
    try std.testing.expect(cookie.isSession());
    try std.testing.expect(!cookie.isExpired());

    // Set expiry in the past
    cookie.expiry_time = std.time.milliTimestamp() - 1000;
    try std.testing.expect(!cookie.isSession());
    try std.testing.expect(cookie.isExpired());

    // Set expiry in the future
    cookie.expiry_time = std.time.milliTimestamp() + 60000;
    try std.testing.expect(!cookie.isExpired());
}

test "Cookie - hasSameIdentity" {
    const allocator = std.testing.allocator;

    var cookie1 = try Cookie.init(allocator, "session", "val1");
    try cookie1.setDomain("example.com");
    try cookie1.setPath("/app");
    defer cookie1.deinit();

    var cookie2 = try Cookie.init(allocator, "session", "val2");
    try cookie2.setDomain("example.com");
    try cookie2.setPath("/app");
    defer cookie2.deinit();

    // Same identity despite different values
    try std.testing.expect(cookie1.hasSameIdentity(cookie2));

    // Different name
    var cookie3 = try Cookie.init(allocator, "other", "val3");
    try cookie3.setDomain("example.com");
    try cookie3.setPath("/app");
    defer cookie3.deinit();

    try std.testing.expect(!cookie1.hasSameIdentity(cookie3));
}

test "CookieListItem - fromCookie" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "name", "value");
    defer cookie.deinit();

    var item = try CookieListItem.fromCookie(allocator, cookie);
    defer item.deinit();

    try std.testing.expectEqualStrings("name", item.name);
    try std.testing.expectEqualStrings("value", item.value);
}
