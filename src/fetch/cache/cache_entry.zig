//! Cache Entry - HTTP Caching
//!
//! This module implements cache entry storage for HTTP caching.
//!
//! Spec: https://fetch.spec.whatwg.org/#http-cache
//!       https://httpwg.org/specs/rfc7234.html

const std = @import("std");
const Allocator = std.mem.Allocator;
const cache_control = @import("cache_control.zig");
const CacheControl = cache_control.CacheControl;
const freshness = @import("freshness.zig");
const CacheTiming = freshness.CacheTiming;

/// A cached HTTP response entry.
pub const CacheEntry = struct {
    allocator: Allocator,

    /// HTTP status code
    status: u16,

    /// Response headers (name-value pairs)
    headers: []Header,

    /// Response body (may be null for HEAD responses)
    body: ?[]const u8,

    /// Cache timing information
    timing: CacheTiming,

    /// ETag for revalidation
    etag: ?[]const u8,

    /// Last-Modified header value string
    last_modified_str: ?[]const u8,

    /// Vary header from response
    vary: ?[]const u8,

    /// Whether this entry has been validated
    validated: bool,

    /// Size of the cached body in bytes
    body_size: usize,

    pub const Header = struct {
        name: []const u8,
        value: []const u8,
    };

    const Self = @This();

    /// Create a cache entry.
    pub fn init(
        allocator: Allocator,
        status: u16,
        headers: []const Header,
        body: ?[]const u8,
        request_time: i64,
        response_time: i64,
    ) !*Self {
        const entry = try allocator.create(Self);
        errdefer allocator.destroy(entry);

        // Copy headers
        const owned_headers = try allocator.alloc(Header, headers.len);
        errdefer allocator.free(owned_headers);

        for (headers, 0..) |h, i| {
            owned_headers[i] = .{
                .name = try allocator.dupe(u8, h.name),
                .value = try allocator.dupe(u8, h.value),
            };
        }

        // Copy body
        const owned_body = if (body) |b| try allocator.dupe(u8, b) else null;

        // Parse cache-relevant headers
        var date_value: i64 = response_time;
        var age_value: u64 = 0;
        var etag: ?[]const u8 = null;
        var last_modified: ?i64 = null;
        var last_modified_str: ?[]const u8 = null;
        var expires: ?i64 = null;
        var vary: ?[]const u8 = null;
        var cc = CacheControl{};

        for (headers) |h| {
            if (std.ascii.eqlIgnoreCase(h.name, "Date")) {
                date_value = freshness.parseHttpDate(h.value) orelse response_time;
            } else if (std.ascii.eqlIgnoreCase(h.name, "Age")) {
                age_value = std.fmt.parseInt(u64, h.value, 10) catch 0;
            } else if (std.ascii.eqlIgnoreCase(h.name, "ETag")) {
                etag = try allocator.dupe(u8, h.value);
            } else if (std.ascii.eqlIgnoreCase(h.name, "Last-Modified")) {
                last_modified = freshness.parseHttpDate(h.value);
                last_modified_str = try allocator.dupe(u8, h.value);
            } else if (std.ascii.eqlIgnoreCase(h.name, "Expires")) {
                expires = freshness.parseHttpDate(h.value);
            } else if (std.ascii.eqlIgnoreCase(h.name, "Vary")) {
                vary = try allocator.dupe(u8, h.value);
            } else if (std.ascii.eqlIgnoreCase(h.name, "Cache-Control")) {
                cc = CacheControl.parse(h.value);
            }
        }

        entry.* = .{
            .allocator = allocator,
            .status = status,
            .headers = owned_headers,
            .body = owned_body,
            .timing = .{
                .request_time = request_time,
                .response_time = response_time,
                .date_value = date_value,
                .age_value = age_value,
                .last_modified = last_modified,
                .expires = expires,
                .cache_control = cc,
            },
            .etag = etag,
            .last_modified_str = last_modified_str,
            .vary = vary,
            .validated = false,
            .body_size = if (body) |b| b.len else 0,
        };

        return entry;
    }

    /// Clean up cache entry.
    pub fn deinit(self: *Self) void {
        for (self.headers) |h| {
            self.allocator.free(h.name);
            self.allocator.free(h.value);
        }
        self.allocator.free(self.headers);

        if (self.body) |b| {
            self.allocator.free(b);
        }
        if (self.etag) |e| {
            self.allocator.free(e);
        }
        if (self.last_modified_str) |lm| {
            self.allocator.free(lm);
        }
        if (self.vary) |v| {
            self.allocator.free(v);
        }

        self.allocator.destroy(self);
    }

    /// Get a header value by name.
    pub fn getHeader(self: *const Self, name: []const u8) ?[]const u8 {
        for (self.headers) |h| {
            if (std.ascii.eqlIgnoreCase(h.name, name)) {
                return h.value;
            }
        }
        return null;
    }

    /// Calculate current age of this entry.
    pub fn currentAge(self: *const Self, now: i64) u64 {
        return freshness.calculateCurrentAge(self.timing, now);
    }

    /// Check if this entry is fresh.
    pub fn isFresh(self: *const Self, is_shared_cache: bool, now: i64) bool {
        return freshness.isFresh(self.timing, is_shared_cache, now);
    }

    /// Check if stale-while-revalidate applies.
    pub fn canServeStaleWhileRevalidate(self: *const Self, is_shared_cache: bool, now: i64) bool {
        return freshness.canServeStaleWhileRevalidate(self.timing, is_shared_cache, now);
    }

    /// Check if stale-if-error applies.
    pub fn canServeStaleIfError(self: *const Self, is_shared_cache: bool, now: i64) bool {
        return freshness.canServeStaleIfError(self.timing, is_shared_cache, now);
    }

    /// Check if response should not have been stored.
    pub fn shouldNotStore(self: *const Self) bool {
        return self.timing.cache_control.shouldNotStore();
    }

    /// Check if response must be revalidated before serving.
    pub fn mustRevalidate(self: *const Self, is_shared_cache: bool) bool {
        return self.timing.cache_control.mustRevalidate(is_shared_cache);
    }

    /// Get time remaining until stale.
    pub fn timeUntilStale(self: *const Self, is_shared_cache: bool, now: i64) u64 {
        return freshness.timeUntilStale(self.timing, is_shared_cache, now);
    }

    /// Check if entry can be used for revalidation (has validators).
    pub fn hasValidators(self: *const Self) bool {
        return self.etag != null or self.last_modified_str != null;
    }

    /// Get total size of entry in bytes (approximate).
    pub fn totalSize(self: *const Self) usize {
        var size: usize = self.body_size;

        // Add header sizes
        for (self.headers) |h| {
            size += h.name.len + h.value.len + 4; // name: value\r\n
        }

        // Add struct overhead
        size += @sizeOf(Self);

        return size;
    }

    /// Update entry after successful revalidation (304 response).
    /// Updates timing information but keeps the body.
    pub fn updateAfterRevalidation(
        self: *Self,
        new_headers: []const Header,
        request_time: i64,
        response_time: i64,
    ) !void {
        // Update timing
        self.timing.request_time = request_time;
        self.timing.response_time = response_time;
        self.timing.date_value = response_time;
        self.timing.age_value = 0;
        self.validated = true;

        // Update cache-relevant headers from 304 response
        for (new_headers) |h| {
            if (std.ascii.eqlIgnoreCase(h.name, "Date")) {
                self.timing.date_value = freshness.parseHttpDate(h.value) orelse response_time;
            } else if (std.ascii.eqlIgnoreCase(h.name, "Cache-Control")) {
                self.timing.cache_control = CacheControl.parse(h.value);
            } else if (std.ascii.eqlIgnoreCase(h.name, "Expires")) {
                self.timing.expires = freshness.parseHttpDate(h.value);
            } else if (std.ascii.eqlIgnoreCase(h.name, "ETag")) {
                if (self.etag) |old| {
                    self.allocator.free(old);
                }
                self.etag = try self.allocator.dupe(u8, h.value);
            } else if (std.ascii.eqlIgnoreCase(h.name, "Last-Modified")) {
                self.timing.last_modified = freshness.parseHttpDate(h.value);
                if (self.last_modified_str) |old| {
                    self.allocator.free(old);
                }
                self.last_modified_str = try self.allocator.dupe(u8, h.value);
            }
        }
    }
};

// =============================================================================
// Tests
// =============================================================================

test "CacheEntry - basic creation" {
    const allocator = std.testing.allocator;

    const headers = [_]CacheEntry.Header{
        .{ .name = "Content-Type", .value = "text/html" },
        .{ .name = "Cache-Control", .value = "max-age=3600" },
    };

    const entry = try CacheEntry.init(
        allocator,
        200,
        &headers,
        "<html>body</html>",
        1000,
        1001,
    );
    defer entry.deinit();

    try std.testing.expectEqual(@as(u16, 200), entry.status);
    try std.testing.expectEqualStrings("<html>body</html>", entry.body.?);
    try std.testing.expectEqual(@as(usize, 2), entry.headers.len);
}

test "CacheEntry - getHeader" {
    const allocator = std.testing.allocator;

    const headers = [_]CacheEntry.Header{
        .{ .name = "Content-Type", .value = "text/html" },
        .{ .name = "X-Custom", .value = "custom-value" },
    };

    const entry = try CacheEntry.init(allocator, 200, &headers, null, 1000, 1001);
    defer entry.deinit();

    try std.testing.expectEqualStrings("text/html", entry.getHeader("Content-Type").?);
    try std.testing.expectEqualStrings("text/html", entry.getHeader("content-type").?);
    try std.testing.expectEqual(@as(?[]const u8, null), entry.getHeader("X-Missing"));
}

test "CacheEntry - parses ETag" {
    const allocator = std.testing.allocator;

    const headers = [_]CacheEntry.Header{
        .{ .name = "ETag", .value = "\"abc123\"" },
    };

    const entry = try CacheEntry.init(allocator, 200, &headers, null, 1000, 1001);
    defer entry.deinit();

    try std.testing.expectEqualStrings("\"abc123\"", entry.etag.?);
    try std.testing.expect(entry.hasValidators());
}

test "CacheEntry - parses Last-Modified" {
    const allocator = std.testing.allocator;

    const headers = [_]CacheEntry.Header{
        .{ .name = "Last-Modified", .value = "Sun, 06 Nov 1994 08:49:37 GMT" },
    };

    const entry = try CacheEntry.init(allocator, 200, &headers, null, 1000, 1001);
    defer entry.deinit();

    try std.testing.expectEqualStrings("Sun, 06 Nov 1994 08:49:37 GMT", entry.last_modified_str.?);
    try std.testing.expect(entry.hasValidators());
}

test "CacheEntry - parses Cache-Control" {
    const allocator = std.testing.allocator;

    const headers = [_]CacheEntry.Header{
        .{ .name = "Cache-Control", .value = "max-age=3600, stale-while-revalidate=60" },
    };

    const entry = try CacheEntry.init(allocator, 200, &headers, null, 1000, 1001);
    defer entry.deinit();

    try std.testing.expectEqual(@as(?u64, 3600), entry.timing.cache_control.max_age);
    try std.testing.expectEqual(@as(?u64, 60), entry.timing.cache_control.stale_while_revalidate);
}

test "CacheEntry - isFresh" {
    const allocator = std.testing.allocator;

    const headers = [_]CacheEntry.Header{
        .{ .name = "Cache-Control", .value = "max-age=3600" },
    };

    const entry = try CacheEntry.init(allocator, 200, &headers, null, 1000, 1001);
    defer entry.deinit();

    // Fresh when current_age < freshness_lifetime
    try std.testing.expect(entry.isFresh(false, 2000)); // age ~1000
    try std.testing.expect(!entry.isFresh(false, 5000)); // age ~4000
}

test "CacheEntry - shouldNotStore" {
    const allocator = std.testing.allocator;

    const headers1 = [_]CacheEntry.Header{
        .{ .name = "Cache-Control", .value = "no-store" },
    };
    const entry1 = try CacheEntry.init(allocator, 200, &headers1, null, 1000, 1001);
    defer entry1.deinit();
    try std.testing.expect(entry1.shouldNotStore());

    const headers2 = [_]CacheEntry.Header{
        .{ .name = "Cache-Control", .value = "max-age=3600" },
    };
    const entry2 = try CacheEntry.init(allocator, 200, &headers2, null, 1000, 1001);
    defer entry2.deinit();
    try std.testing.expect(!entry2.shouldNotStore());
}

test "CacheEntry - mustRevalidate" {
    const allocator = std.testing.allocator;

    const headers = [_]CacheEntry.Header{
        .{ .name = "Cache-Control", .value = "must-revalidate" },
    };

    const entry = try CacheEntry.init(allocator, 200, &headers, null, 1000, 1001);
    defer entry.deinit();

    try std.testing.expect(entry.mustRevalidate(false));
}

test "CacheEntry - totalSize" {
    const allocator = std.testing.allocator;

    const headers = [_]CacheEntry.Header{
        .{ .name = "Content-Type", .value = "text/html" },
    };

    const body = "Hello, World!";
    const entry = try CacheEntry.init(allocator, 200, &headers, body, 1000, 1001);
    defer entry.deinit();

    const size = entry.totalSize();
    try std.testing.expect(size >= body.len);
}

test "CacheEntry - updateAfterRevalidation" {
    const allocator = std.testing.allocator;

    const headers = [_]CacheEntry.Header{
        .{ .name = "Cache-Control", .value = "max-age=3600" },
        .{ .name = "ETag", .value = "\"old\"" },
    };

    const entry = try CacheEntry.init(allocator, 200, &headers, "body", 1000, 1001);
    defer entry.deinit();

    // Simulate 304 response
    const new_headers = [_]CacheEntry.Header{
        .{ .name = "Cache-Control", .value = "max-age=7200" },
        .{ .name = "ETag", .value = "\"new\"" },
    };

    try entry.updateAfterRevalidation(&new_headers, 5000, 5001);

    try std.testing.expect(entry.validated);
    try std.testing.expectEqual(@as(?u64, 7200), entry.timing.cache_control.max_age);
    try std.testing.expectEqualStrings("\"new\"", entry.etag.?);
    try std.testing.expectEqualStrings("body", entry.body.?); // Body preserved
}
