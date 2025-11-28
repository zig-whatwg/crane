//! Cookie Structure per RFC 6265bis
//!
//! Spec: https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
//!
//! This module defines the Cookie struct that represents an HTTP cookie
//! with all RFC 6265bis attributes.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// SameSite attribute values per RFC 6265bis.
pub const SameSite = enum {
    /// Cookie is sent only with same-site requests
    strict,

    /// Cookie is sent with same-site requests and top-level cross-site GET
    lax,

    /// Cookie is sent with all requests (requires Secure)
    none,

    /// No SameSite attribute specified (defaults to Lax behavior)
    default,

    /// Parse SameSite attribute value.
    pub fn parse(value: []const u8) SameSite {
        const trimmed = std.mem.trim(u8, value, " \t");
        if (eqlIgnoreCase(trimmed, "Strict")) return .strict;
        if (eqlIgnoreCase(trimmed, "Lax")) return .lax;
        if (eqlIgnoreCase(trimmed, "None")) return .none;
        return .default; // Unknown values treated as default
    }

    /// Convert to string representation.
    pub fn toString(self: SameSite) ?[]const u8 {
        return switch (self) {
            .strict => "Strict",
            .lax => "Lax",
            .none => "None",
            .default => null,
        };
    }
};

/// A cookie per RFC 6265bis.
pub const Cookie = struct {
    allocator: Allocator,

    /// Cookie name
    name: []const u8,

    /// Cookie value
    value: []const u8,

    /// Domain attribute (null if not set, meaning host-only)
    domain: ?[]const u8 = null,

    /// Path attribute (default "/")
    path: []const u8,

    /// Expiry time as Unix timestamp (null for session cookie)
    expiry_time: ?i64 = null,

    /// Creation time as Unix timestamp
    creation_time: i64,

    /// Last access time as Unix timestamp
    last_access_time: i64,

    /// Secure-only flag (cookie only sent over HTTPS)
    secure_only: bool = false,

    /// HttpOnly flag (cookie not accessible to scripts)
    http_only: bool = false,

    /// SameSite attribute
    same_site: SameSite = .default,

    /// Host-only flag (domain exactly matches, no subdomains)
    host_only: bool = true,

    /// Partitioned flag (CHIPS)
    partitioned: bool = false,

    const Self = @This();

    /// Initialize a cookie with required fields.
    pub fn init(
        allocator: Allocator,
        name: []const u8,
        value: []const u8,
        path: ?[]const u8,
    ) !Self {
        const now = std.time.timestamp();

        const owned_name = try allocator.dupe(u8, name);
        errdefer allocator.free(owned_name);

        const owned_value = try allocator.dupe(u8, value);
        errdefer allocator.free(owned_value);

        const owned_path = try allocator.dupe(u8, path orelse "/");

        return .{
            .allocator = allocator,
            .name = owned_name,
            .value = owned_value,
            .path = owned_path,
            .creation_time = now,
            .last_access_time = now,
        };
    }

    /// Free all owned memory.
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
        self.allocator.free(self.value);
        self.allocator.free(self.path);
        if (self.domain) |d| {
            self.allocator.free(d);
        }
    }

    /// Check if cookie is expired.
    pub fn isExpired(self: Self) bool {
        if (self.expiry_time) |exp| {
            return exp <= std.time.timestamp();
        }
        return false; // Session cookies don't expire based on time
    }

    /// Check if cookie is a session cookie (no expiry).
    pub fn isSession(self: Self) bool {
        return self.expiry_time == null;
    }

    /// Set domain attribute (takes ownership of the string if owned).
    pub fn setDomain(self: *Self, domain: []const u8) !void {
        if (self.domain) |old| {
            self.allocator.free(old);
        }
        self.domain = try self.allocator.dupe(u8, domain);
        self.host_only = false;
    }

    /// Update last access time.
    pub fn touch(self: *Self) void {
        self.last_access_time = std.time.timestamp();
    }

    /// Clone the cookie.
    pub fn clone(self: Self, allocator: Allocator) !Self {
        const owned_name = try allocator.dupe(u8, self.name);
        errdefer allocator.free(owned_name);

        const owned_value = try allocator.dupe(u8, self.value);
        errdefer allocator.free(owned_value);

        const owned_path = try allocator.dupe(u8, self.path);
        errdefer allocator.free(owned_path);

        var result = Self{
            .allocator = allocator,
            .name = owned_name,
            .value = owned_value,
            .path = owned_path,
            .expiry_time = self.expiry_time,
            .creation_time = self.creation_time,
            .last_access_time = self.last_access_time,
            .secure_only = self.secure_only,
            .http_only = self.http_only,
            .same_site = self.same_site,
            .host_only = self.host_only,
            .partitioned = self.partitioned,
        };

        if (self.domain) |d| {
            result.domain = try allocator.dupe(u8, d);
        }

        return result;
    }
};

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

test "Cookie.init creates cookie with defaults" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "session", "abc123", null);
    defer cookie.deinit();

    try std.testing.expectEqualStrings("session", cookie.name);
    try std.testing.expectEqualStrings("abc123", cookie.value);
    try std.testing.expectEqualStrings("/", cookie.path);
    try std.testing.expect(cookie.expiry_time == null);
    try std.testing.expect(cookie.isSession());
    try std.testing.expect(!cookie.isExpired());
    try std.testing.expect(cookie.host_only);
}

test "Cookie.init with custom path" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "token", "xyz", "/api");
    defer cookie.deinit();

    try std.testing.expectEqualStrings("/api", cookie.path);
}

test "Cookie.setDomain" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "test", "value", null);
    defer cookie.deinit();

    try std.testing.expect(cookie.host_only);
    try std.testing.expect(cookie.domain == null);

    try cookie.setDomain("example.com");

    try std.testing.expect(!cookie.host_only);
    try std.testing.expectEqualStrings("example.com", cookie.domain.?);
}

test "Cookie.isExpired" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "test", "value", null);
    defer cookie.deinit();

    // Session cookie - not expired
    try std.testing.expect(!cookie.isExpired());

    // Set expiry in the past
    cookie.expiry_time = std.time.timestamp() - 1000;
    try std.testing.expect(cookie.isExpired());

    // Set expiry in the future
    cookie.expiry_time = std.time.timestamp() + 1000;
    try std.testing.expect(!cookie.isExpired());
}

test "Cookie.clone" {
    const allocator = std.testing.allocator;

    var original = try Cookie.init(allocator, "test", "value", "/path");
    defer original.deinit();

    original.secure_only = true;
    original.http_only = true;
    original.same_site = .strict;
    try original.setDomain("example.com");

    var cloned = try original.clone(allocator);
    defer cloned.deinit();

    try std.testing.expectEqualStrings("test", cloned.name);
    try std.testing.expectEqualStrings("value", cloned.value);
    try std.testing.expectEqualStrings("/path", cloned.path);
    try std.testing.expectEqualStrings("example.com", cloned.domain.?);
    try std.testing.expect(cloned.secure_only);
    try std.testing.expect(cloned.http_only);
    try std.testing.expectEqual(SameSite.strict, cloned.same_site);
}

test "SameSite.parse" {
    try std.testing.expectEqual(SameSite.strict, SameSite.parse("Strict"));
    try std.testing.expectEqual(SameSite.strict, SameSite.parse("strict"));
    try std.testing.expectEqual(SameSite.strict, SameSite.parse("STRICT"));
    try std.testing.expectEqual(SameSite.lax, SameSite.parse("Lax"));
    try std.testing.expectEqual(SameSite.none, SameSite.parse("None"));
    try std.testing.expectEqual(SameSite.default, SameSite.parse("invalid"));
    try std.testing.expectEqual(SameSite.default, SameSite.parse(""));
}

test "SameSite.toString" {
    try std.testing.expectEqualStrings("Strict", SameSite.strict.toString().?);
    try std.testing.expectEqualStrings("Lax", SameSite.lax.toString().?);
    try std.testing.expectEqualStrings("None", SameSite.none.toString().?);
    try std.testing.expect(SameSite.default.toString() == null);
}
