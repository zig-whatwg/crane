//! Cache Key - HTTP Caching
//!
//! This module implements cache key generation and matching for HTTP caching.
//!
//! Spec: https://fetch.spec.whatwg.org/#http-cache-partitions
//!
//! Cache keys include:
//! - URL (normalized)
//! - HTTP method (typically only GET/HEAD are cached)
//! - Network partition key (for cache partitioning)
//! - Vary header values (for content negotiation)

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Vary header entry for content negotiation.
pub const VaryEntry = struct {
    header_name: []const u8,
    header_value: []const u8,
};

/// Cache key for HTTP cache lookups.
///
/// Per Fetch spec, cache partitioning uses:
/// - Top-level site (network partition key)
/// - Request URL
/// - Vary headers from response
pub const CacheKey = struct {
    allocator: Allocator,

    /// URL (normalized, without fragment)
    url: []const u8,

    /// HTTP method (uppercase)
    method: []const u8,

    /// Network partition key for cache partitioning.
    /// Format: (top_level_site, frame_site) as string.
    /// Example: "https://example.com,https://example.com"
    partition_key: ?[]const u8,

    /// Vary header values from the request.
    /// Used to match content negotiation.
    vary_entries: []VaryEntry,

    const Self = @This();

    /// Create a cache key from components.
    pub fn init(
        allocator: Allocator,
        url: []const u8,
        method: []const u8,
        partition_key: ?[]const u8,
    ) !*Self {
        const key = try allocator.create(Self);
        errdefer allocator.destroy(key);

        key.* = .{
            .allocator = allocator,
            .url = try normalizeUrl(allocator, url),
            .method = try normalizeMethod(allocator, method),
            .partition_key = if (partition_key) |pk| try allocator.dupe(u8, pk) else null,
            .vary_entries = &.{},
        };

        return key;
    }

    /// Clean up cache key.
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.url);
        self.allocator.free(self.method);
        if (self.partition_key) |pk| {
            self.allocator.free(pk);
        }
        for (self.vary_entries) |entry| {
            self.allocator.free(entry.header_name);
            self.allocator.free(entry.header_value);
        }
        if (self.vary_entries.len > 0) {
            self.allocator.free(self.vary_entries);
        }
        self.allocator.destroy(self);
    }

    /// Set Vary header entries for this key.
    pub fn setVaryEntries(self: *Self, entries: []const VaryEntry) !void {
        // Free existing entries
        for (self.vary_entries) |entry| {
            self.allocator.free(entry.header_name);
            self.allocator.free(entry.header_value);
        }
        if (self.vary_entries.len > 0) {
            self.allocator.free(self.vary_entries);
        }

        // Copy new entries
        if (entries.len == 0) {
            self.vary_entries = &.{};
            return;
        }

        const new_entries = try self.allocator.alloc(VaryEntry, entries.len);
        for (entries, 0..) |entry, i| {
            new_entries[i] = .{
                .header_name = try self.allocator.dupe(u8, entry.header_name),
                .header_value = try self.allocator.dupe(u8, entry.header_value),
            };
        }
        self.vary_entries = new_entries;
    }

    /// Check if this key matches another key.
    ///
    /// For a match:
    /// - URL must be equal
    /// - Method must be equal
    /// - Partition key must be equal (if present)
    /// - All Vary entries must match
    pub fn matches(self: *const Self, other: *const Self) bool {
        // URL must match
        if (!std.mem.eql(u8, self.url, other.url)) {
            return false;
        }

        // Method must match
        if (!std.ascii.eqlIgnoreCase(self.method, other.method)) {
            return false;
        }

        // Partition key must match
        const self_pk = self.partition_key orelse "";
        const other_pk = other.partition_key orelse "";
        if (!std.mem.eql(u8, self_pk, other_pk)) {
            return false;
        }

        // Vary entries must match
        if (self.vary_entries.len != other.vary_entries.len) {
            return false;
        }
        for (self.vary_entries) |entry| {
            const found = for (other.vary_entries) |other_entry| {
                if (std.ascii.eqlIgnoreCase(entry.header_name, other_entry.header_name) and
                    std.mem.eql(u8, entry.header_value, other_entry.header_value))
                {
                    break true;
                }
            } else false;
            if (!found) return false;
        }

        return true;
    }

    /// Check if cached response's Vary header allows serving this request.
    ///
    /// response_vary: The Vary header value from the cached response.
    /// request_headers: The headers from the current request.
    ///
    /// Returns true if the request headers match the cached Vary requirements.
    pub fn matchesVary(
        self: *const Self,
        response_vary: ?[]const u8,
        request_headers: anytype, // Type with get(name) method
    ) bool {
        const vary = response_vary orelse return true;

        // Vary: * means response varies by something not in headers
        if (std.mem.eql(u8, std.mem.trim(u8, vary, " \t"), "*")) {
            return false;
        }

        // Parse comma-separated header names
        var iter = std.mem.splitScalar(u8, vary, ',');
        while (iter.next()) |part| {
            const header_name = std.mem.trim(u8, part, " \t");
            if (header_name.len == 0) continue;

            // Find the stored value for this header
            const stored_value = for (self.vary_entries) |entry| {
                if (std.ascii.eqlIgnoreCase(entry.header_name, header_name)) {
                    break entry.header_value;
                }
            } else "";

            // Get current request value
            const current_value = request_headers.get(header_name) orelse "";

            // Values must match
            if (!std.mem.eql(u8, stored_value, current_value)) {
                return false;
            }
        }

        return true;
    }

    /// Generate a string key for hash map storage.
    /// Format: "partition_key|method|url"
    pub fn toHashKey(self: *const Self, allocator: Allocator) ![]const u8 {
        const pk = self.partition_key orelse "";
        return std.fmt.allocPrint(allocator, "{s}|{s}|{s}", .{ pk, self.method, self.url });
    }
};

/// Normalize URL for cache key.
/// - Remove fragment
/// - Preserve scheme, host, path, query
fn normalizeUrl(allocator: Allocator, url: []const u8) ![]const u8 {
    // Remove fragment (everything after #)
    const without_fragment = if (std.mem.indexOf(u8, url, "#")) |pos|
        url[0..pos]
    else
        url;

    return allocator.dupe(u8, without_fragment);
}

/// Normalize method for cache key.
/// - Uppercase common methods
fn normalizeMethod(allocator: Allocator, method: []const u8) ![]const u8 {
    var normalized = try allocator.alloc(u8, method.len);
    for (method, 0..) |c, i| {
        normalized[i] = std.ascii.toUpper(c);
    }
    return normalized;
}

/// Check if a method is cacheable.
/// Per HTTP spec, only GET and HEAD responses are cacheable by default.
pub fn isCacheableMethod(method: []const u8) bool {
    return std.ascii.eqlIgnoreCase(method, "GET") or
        std.ascii.eqlIgnoreCase(method, "HEAD");
}

/// Check if a status code is cacheable by default.
/// Per RFC 7231 § 6.1.
pub fn isCacheableStatus(status: u16) bool {
    return switch (status) {
        200, 203, 204, 206 => true,
        300, 301, 308 => true,
        404, 405, 410, 414 => true,
        501 => true,
        else => false,
    };
}

// =============================================================================
// Tests
// =============================================================================

test "CacheKey - basic creation" {
    const allocator = std.testing.allocator;

    const key = try CacheKey.init(allocator, "https://example.com/path?query=1", "GET", null);
    defer key.deinit();

    try std.testing.expectEqualStrings("https://example.com/path?query=1", key.url);
    try std.testing.expectEqualStrings("GET", key.method);
    try std.testing.expectEqual(@as(?[]const u8, null), key.partition_key);
}

test "CacheKey - URL normalization removes fragment" {
    const allocator = std.testing.allocator;

    const key = try CacheKey.init(allocator, "https://example.com/path#section", "GET", null);
    defer key.deinit();

    try std.testing.expectEqualStrings("https://example.com/path", key.url);
}

test "CacheKey - method normalization" {
    const allocator = std.testing.allocator;

    const key = try CacheKey.init(allocator, "https://example.com/", "get", null);
    defer key.deinit();

    try std.testing.expectEqualStrings("GET", key.method);
}

test "CacheKey - with partition key" {
    const allocator = std.testing.allocator;

    const key = try CacheKey.init(
        allocator,
        "https://api.example.com/data",
        "GET",
        "https://example.com,https://example.com",
    );
    defer key.deinit();

    try std.testing.expectEqualStrings("https://example.com,https://example.com", key.partition_key.?);
}

test "CacheKey - matches same key" {
    const allocator = std.testing.allocator;

    const key1 = try CacheKey.init(allocator, "https://example.com/", "GET", null);
    defer key1.deinit();

    const key2 = try CacheKey.init(allocator, "https://example.com/", "GET", null);
    defer key2.deinit();

    try std.testing.expect(key1.matches(key2));
}

test "CacheKey - does not match different URL" {
    const allocator = std.testing.allocator;

    const key1 = try CacheKey.init(allocator, "https://example.com/a", "GET", null);
    defer key1.deinit();

    const key2 = try CacheKey.init(allocator, "https://example.com/b", "GET", null);
    defer key2.deinit();

    try std.testing.expect(!key1.matches(key2));
}

test "CacheKey - does not match different method" {
    const allocator = std.testing.allocator;

    const key1 = try CacheKey.init(allocator, "https://example.com/", "GET", null);
    defer key1.deinit();

    const key2 = try CacheKey.init(allocator, "https://example.com/", "HEAD", null);
    defer key2.deinit();

    try std.testing.expect(!key1.matches(key2));
}

test "CacheKey - partition key matching" {
    const allocator = std.testing.allocator;

    const key1 = try CacheKey.init(allocator, "https://example.com/", "GET", "https://a.com,https://a.com");
    defer key1.deinit();

    const key2 = try CacheKey.init(allocator, "https://example.com/", "GET", "https://b.com,https://b.com");
    defer key2.deinit();

    try std.testing.expect(!key1.matches(key2));
}

test "CacheKey - toHashKey" {
    const allocator = std.testing.allocator;

    const key = try CacheKey.init(allocator, "https://example.com/", "GET", "pk");
    defer key.deinit();

    const hash_key = try key.toHashKey(allocator);
    defer allocator.free(hash_key);

    try std.testing.expectEqualStrings("pk|GET|https://example.com/", hash_key);
}

test "isCacheableMethod" {
    try std.testing.expect(isCacheableMethod("GET"));
    try std.testing.expect(isCacheableMethod("get"));
    try std.testing.expect(isCacheableMethod("HEAD"));
    try std.testing.expect(isCacheableMethod("head"));
    try std.testing.expect(!isCacheableMethod("POST"));
    try std.testing.expect(!isCacheableMethod("PUT"));
    try std.testing.expect(!isCacheableMethod("DELETE"));
}

test "isCacheableStatus" {
    try std.testing.expect(isCacheableStatus(200));
    try std.testing.expect(isCacheableStatus(301));
    try std.testing.expect(isCacheableStatus(404));
    try std.testing.expect(!isCacheableStatus(201));
    try std.testing.expect(!isCacheableStatus(302));
    try std.testing.expect(!isCacheableStatus(500));
}

test "CacheKey - setVaryEntries" {
    const allocator = std.testing.allocator;

    const key = try CacheKey.init(allocator, "https://example.com/", "GET", null);
    defer key.deinit();

    const entries = [_]VaryEntry{
        .{ .header_name = "Accept", .header_value = "application/json" },
        .{ .header_name = "Accept-Language", .header_value = "en-US" },
    };

    try key.setVaryEntries(&entries);

    try std.testing.expectEqual(@as(usize, 2), key.vary_entries.len);
    try std.testing.expectEqualStrings("Accept", key.vary_entries[0].header_name);
    try std.testing.expectEqualStrings("application/json", key.vary_entries[0].header_value);
}
