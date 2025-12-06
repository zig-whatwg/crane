//! Cookie Storage Persistence Integration
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//! WHATWG Storage Standard: https://storage.spec.whatwg.org/
//!
//! This module provides persistence for cookies using the Storage Standard
//! infrastructure. Cookies are serialized to JSON and stored in the
//! cookies storage bottle.

const std = @import("std");
const Cookie = @import("cookie.zig").Cookie;
const SameSite = @import("cookie.zig").SameSite;
const PartitionKey = @import("cookie.zig").PartitionKey;
const CookieJar = @import("jar.zig").CookieJar;

/// Cookie storage area that integrates with the Storage Standard
pub const CookieStorageArea = struct {
    /// The backing CookieJar for this storage area
    jar: CookieJar,

    /// Origin for this storage area
    origin: []const u8,

    /// Allocator
    allocator: std.mem.Allocator,

    /// Whether storage has been loaded
    loaded: bool = false,

    const Self = @This();

    /// Create a new storage area for an origin
    pub fn init(allocator: std.mem.Allocator, origin: []const u8) !Self {
        return Self{
            .jar = CookieJar.init(allocator),
            .origin = try allocator.dupe(u8, origin),
            .allocator = allocator,
            .loaded = false,
        };
    }

    /// Free all resources
    pub fn deinit(self: *Self) void {
        self.jar.deinit();
        self.allocator.free(self.origin);
        self.* = undefined;
    }

    /// Get the CookieJar (loads from storage if not already loaded)
    pub fn getJar(self: *Self) *CookieJar {
        if (!self.loaded) {
            // In a full implementation, this would load from Storage Standard
            // For now, we start with an empty jar
            self.loaded = true;
        }
        return &self.jar;
    }

    /// Generate a storage key for a cookie
    /// Format: name|domain|path
    pub fn generateKey(allocator: std.mem.Allocator, cookie: Cookie) ![]u8 {
        const domain = cookie.domain orelse "";
        return std.fmt.allocPrint(allocator, "{s}|{s}|{s}", .{ cookie.name, domain, cookie.path });
    }

    /// Serialize a cookie to JSON
    pub fn serializeCookie(allocator: std.mem.Allocator, cookie: Cookie) ![]u8 {
        var list = std.ArrayListUnmanaged(u8){};
        errdefer list.deinit(allocator);

        const writer = list.writer(allocator);

        try writer.writeAll("{");

        // Name
        try writer.writeAll("\"name\":\"");
        try writeJsonEscaped(writer, cookie.name);
        try writer.writeAll("\",");

        // Value
        try writer.writeAll("\"value\":\"");
        try writeJsonEscaped(writer, cookie.value);
        try writer.writeAll("\",");

        // Domain
        try writer.writeAll("\"domain\":");
        if (cookie.domain) |d| {
            try writer.writeAll("\"");
            try writeJsonEscaped(writer, d);
            try writer.writeAll("\"");
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",");

        // Path
        try writer.writeAll("\"path\":\"");
        try writeJsonEscaped(writer, cookie.path);
        try writer.writeAll("\",");

        // Expiry
        try writer.writeAll("\"expiry_time\":");
        if (cookie.expiry_time) |exp| {
            try writer.print("{d}", .{exp});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",");

        // Creation time
        try writer.print("\"creation_time\":{d},", .{cookie.creation_time});

        // Last access time
        try writer.print("\"last_access_time\":{d},", .{cookie.last_access_time});

        // Boolean flags
        try writer.print("\"secure\":{},", .{cookie.secure});
        try writer.print("\"http_only\":{},", .{cookie.http_only});
        try writer.print("\"host_only\":{},", .{cookie.host_only});

        // SameSite
        try writer.writeAll("\"same_site\":\"");
        try writer.writeAll(cookie.same_site.toString());
        try writer.writeAll("\"");

        // Partition key (optional)
        if (cookie.partition_key) |pk| {
            try writer.writeAll(",\"partition_key\":\"");
            try writeJsonEscaped(writer, pk.top_level_site);
            try writer.writeAll("\"");
        }

        try writer.writeAll("}");

        return list.toOwnedSlice(allocator);
    }

    /// Deserialize a cookie from JSON
    pub fn deserializeCookie(allocator: std.mem.Allocator, json: []const u8) !Cookie {
        // Simple JSON parsing (in production, use a proper JSON parser)
        var cookie = Cookie{
            .name = "",
            .value = "",
            .creation_time = 0,
            .last_access_time = 0,
            .allocator = allocator,
        };

        // Parse name
        if (findJsonString(json, "name")) |name| {
            cookie.name = try allocator.dupe(u8, name);
        }

        // Parse value
        if (findJsonString(json, "value")) |value| {
            cookie.value = try allocator.dupe(u8, value);
        }

        // Parse domain
        if (findJsonString(json, "domain")) |domain| {
            cookie.domain = try allocator.dupe(u8, domain);
            cookie.host_only = false;
        }

        // Parse path
        if (findJsonString(json, "path")) |path| {
            if (std.mem.eql(u8, path, "/")) {
                cookie.path = "/";
            } else {
                cookie.path = try allocator.dupe(u8, path);
            }
        }

        // Parse expiry_time
        if (findJsonNumber(json, "expiry_time")) |exp| {
            cookie.expiry_time = exp;
        }

        // Parse creation_time
        if (findJsonNumber(json, "creation_time")) |ct| {
            cookie.creation_time = ct;
        }

        // Parse last_access_time
        if (findJsonNumber(json, "last_access_time")) |lat| {
            cookie.last_access_time = lat;
        }

        // Parse booleans
        cookie.secure = findJsonBool(json, "secure") orelse false;
        cookie.http_only = findJsonBool(json, "http_only") orelse false;
        cookie.host_only = findJsonBool(json, "host_only") orelse true;

        // Parse same_site
        if (findJsonString(json, "same_site")) |ss| {
            cookie.same_site = SameSite.fromString(ss) orelse .lax;
        }

        // Parse partition_key
        if (findJsonString(json, "partition_key")) |pk| {
            cookie.partition_key = try PartitionKey.init(allocator, pk);
        }

        return cookie;
    }

    /// Save a cookie to storage
    /// In a full implementation, this would persist to the Storage Standard bottle.
    /// Currently a no-op - cookies live in memory only.
    pub fn saveCookie(self: *Self, cookie: Cookie) !void {
        // TODO: Implement persistence to Storage Standard
        // 1. Get the storage bottle for this origin via obtainLocalStorageBottleMap
        // 2. Generate key and serialize cookie
        // 3. Store key -> json in the bottle's proxy map
        _ = self;
        _ = cookie;
    }

    /// Remove a cookie from storage
    /// In a full implementation, this would remove from the Storage Standard bottle.
    /// Currently a no-op.
    pub fn removeCookie(self: *Self, cookie: Cookie) !void {
        // TODO: Implement removal from Storage Standard
        // 1. Get the storage bottle for this origin
        // 2. Generate key
        // 3. Delete the key from the bottle's proxy map
        _ = self;
        _ = cookie;
    }

    /// Clear all cookies for this origin
    pub fn clearAll(self: *Self) void {
        self.jar.clear();

        // In a full implementation, this would:
        // 1. Get the storage bottle for this origin
        // 2. Clear all entries in the bottle's proxy map
    }
};

/// Write a JSON-escaped string
fn writeJsonEscaped(writer: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                if (c < 0x20) {
                    try writer.print("\\u{x:0>4}", .{c});
                } else {
                    try writer.writeByte(c);
                }
            },
        }
    }
}

/// Simple JSON string finder
fn findJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    // Look for "key":"value" pattern
    var search_buf: [128]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":\"", .{key}) catch return null;

    if (std.mem.indexOf(u8, json, search)) |start| {
        const value_start = start + search.len;
        // Find closing quote (not escaped)
        var i = value_start;
        while (i < json.len) {
            if (json[i] == '"' and (i == value_start or json[i - 1] != '\\')) {
                return json[value_start..i];
            }
            i += 1;
        }
    }
    return null;
}

/// Simple JSON number finder
fn findJsonNumber(json: []const u8, key: []const u8) ?i64 {
    var search_buf: [128]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":", .{key}) catch return null;

    if (std.mem.indexOf(u8, json, search)) |start| {
        var value_start = start + search.len;
        // Skip whitespace
        while (value_start < json.len and (json[value_start] == ' ' or json[value_start] == '\t')) {
            value_start += 1;
        }

        if (value_start >= json.len) return null;

        // Check for null
        if (std.mem.startsWith(u8, json[value_start..], "null")) {
            return null;
        }

        // Find end of number
        var end = value_start;
        if (end < json.len and json[end] == '-') end += 1;
        while (end < json.len and std.ascii.isDigit(json[end])) {
            end += 1;
        }

        if (end > value_start) {
            return std.fmt.parseInt(i64, json[value_start..end], 10) catch null;
        }
    }
    return null;
}

/// Simple JSON boolean finder
fn findJsonBool(json: []const u8, key: []const u8) ?bool {
    var search_buf: [128]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":", .{key}) catch return null;

    if (std.mem.indexOf(u8, json, search)) |start| {
        const rest = json[start + search.len ..];
        if (std.mem.startsWith(u8, rest, "true")) return true;
        if (std.mem.startsWith(u8, rest, "false")) return false;
    }
    return null;
}

// ============================================================================
// Tests
// ============================================================================

test "CookieStorageArea - init and deinit" {
    const allocator = std.testing.allocator;

    var area = try CookieStorageArea.init(allocator, "https://example.com");
    defer area.deinit();

    try std.testing.expectEqualStrings("https://example.com", area.origin);
}

test "CookieStorageArea - getJar" {
    const allocator = std.testing.allocator;

    var area = try CookieStorageArea.init(allocator, "https://example.com");
    defer area.deinit();

    const jar = area.getJar();
    try std.testing.expectEqual(@as(usize, 0), jar.count());
    try std.testing.expect(area.loaded);
}

test "generateKey" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "session", "abc");
    defer cookie.deinit();
    try cookie.setDomain("example.com");
    try cookie.setPath("/app");

    const key = try CookieStorageArea.generateKey(allocator, cookie);
    defer allocator.free(key);

    try std.testing.expectEqualStrings("session|example.com|/app", key);
}

test "serializeCookie and deserializeCookie" {
    const allocator = std.testing.allocator;

    // Create a cookie
    var original = try Cookie.init(allocator, "test", "value123");
    defer original.deinit();
    original.secure = true;
    original.same_site = .strict;
    try original.setDomain("example.com");
    try original.setPath("/api");
    original.expiry_time = 1700000000000;

    // Serialize
    const json = try CookieStorageArea.serializeCookie(allocator, original);
    defer allocator.free(json);

    // Deserialize
    var restored = try CookieStorageArea.deserializeCookie(allocator, json);
    defer restored.deinit();

    // Verify
    try std.testing.expectEqualStrings("test", restored.name);
    try std.testing.expectEqualStrings("value123", restored.value);
    try std.testing.expectEqualStrings("example.com", restored.domain.?);
    try std.testing.expectEqualStrings("/api", restored.path);
    try std.testing.expect(restored.secure);
    try std.testing.expectEqual(SameSite.strict, restored.same_site);
    try std.testing.expectEqual(@as(?i64, 1700000000000), restored.expiry_time);
}

test "serializeCookie - session cookie" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "session", "data");
    defer cookie.deinit();
    // No expiry (session cookie)

    const json = try CookieStorageArea.serializeCookie(allocator, cookie);
    defer allocator.free(json);

    // Check that expiry is null
    try std.testing.expect(std.mem.indexOf(u8, json, "\"expiry_time\":null") != null);
}

test "JSON escape handling" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "name", "value\"with\\quotes");
    defer cookie.deinit();

    const json = try CookieStorageArea.serializeCookie(allocator, cookie);
    defer allocator.free(json);

    // Verify escaping
    try std.testing.expect(std.mem.indexOf(u8, json, "\\\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\\\\") != null);
}
