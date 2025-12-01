//! Cache API Types
//!
//! Supporting types for the Cache API.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#cache-interface

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import shared types from parent module
const sw_types = @import("../types.zig");
pub const CacheQueryOptions = sw_types.CacheQueryOptions;
pub const MultiCacheQueryOptions = sw_types.MultiCacheQueryOptions;

/// HTTP header entry.
pub const HeaderEntry = struct {
    name: []const u8,
    value: []const u8,
};

/// Response type for stored responses.
pub const ResponseType = enum {
    basic,
    cors,
    default,
    err,
    opaque_response,
    opaqueredirect,

    pub fn getName(self: ResponseType) []const u8 {
        return switch (self) {
            .basic => "basic",
            .cors => "cors",
            .default => "default",
            .err => "error",
            .opaque_response => "opaque",
            .opaqueredirect => "opaqueredirect",
        };
    }
};

/// Stored request in cache.
pub const StoredRequest = struct {
    allocator: Allocator,

    /// Request URL.
    url: []const u8,

    /// HTTP method.
    method: []const u8,

    /// Request headers.
    headers: []HeaderEntry,

    const Self = @This();

    pub fn init(allocator: Allocator, url: []const u8, method: []const u8, headers: []const HeaderEntry) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const url_copy = try allocator.dupe(u8, url);
        errdefer allocator.free(url_copy);

        const method_copy = try allocator.dupe(u8, method);
        errdefer allocator.free(method_copy);

        // Copy headers
        const headers_copy = try allocator.alloc(HeaderEntry, headers.len);
        errdefer allocator.free(headers_copy);

        for (headers, 0..) |header, i| {
            headers_copy[i] = .{
                .name = try allocator.dupe(u8, header.name),
                .value = try allocator.dupe(u8, header.value),
            };
        }

        self.* = .{
            .allocator = allocator,
            .url = url_copy,
            .method = method_copy,
            .headers = headers_copy,
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        for (self.headers) |header| {
            self.allocator.free(header.name);
            self.allocator.free(header.value);
        }
        self.allocator.free(self.headers);
        self.allocator.free(self.method);
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }

    /// Get a header value by name (case-insensitive).
    pub fn getHeader(self: *const Self, name: []const u8) ?[]const u8 {
        for (self.headers) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, name)) {
                return header.value;
            }
        }
        return null;
    }
};

/// Stored response in cache.
pub const StoredResponse = struct {
    allocator: Allocator,

    /// HTTP status code.
    status: u16,

    /// HTTP status text.
    status_text: []const u8,

    /// Response headers.
    headers: []HeaderEntry,

    /// Response body (stored bytes).
    body: ?[]const u8,

    /// Response type.
    response_type: ResponseType,

    const Self = @This();

    pub fn init(
        allocator: Allocator,
        status: u16,
        status_text: []const u8,
        headers: []const HeaderEntry,
        body: ?[]const u8,
        response_type: ResponseType,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const status_text_copy = try allocator.dupe(u8, status_text);
        errdefer allocator.free(status_text_copy);

        // Copy headers
        const headers_copy = try allocator.alloc(HeaderEntry, headers.len);
        errdefer allocator.free(headers_copy);

        for (headers, 0..) |header, i| {
            headers_copy[i] = .{
                .name = try allocator.dupe(u8, header.name),
                .value = try allocator.dupe(u8, header.value),
            };
        }

        // Copy body if present
        const body_copy = if (body) |b| try allocator.dupe(u8, b) else null;

        self.* = .{
            .allocator = allocator,
            .status = status,
            .status_text = status_text_copy,
            .headers = headers_copy,
            .body = body_copy,
            .response_type = response_type,
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        for (self.headers) |header| {
            self.allocator.free(header.name);
            self.allocator.free(header.value);
        }
        self.allocator.free(self.headers);
        self.allocator.free(self.status_text);
        if (self.body) |b| {
            self.allocator.free(b);
        }
        self.allocator.destroy(self);
    }

    /// Get a header value by name (case-insensitive).
    pub fn getHeader(self: *const Self, name: []const u8) ?[]const u8 {
        for (self.headers) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, name)) {
                return header.value;
            }
        }
        return null;
    }

    /// Check if response is successful (2xx).
    pub fn isOk(self: *const Self) bool {
        return self.status >= 200 and self.status < 300;
    }
};

/// Cache entry (request + response pair).
pub const CacheEntry = struct {
    allocator: Allocator,

    /// The stored request.
    request: *StoredRequest,

    /// The stored response.
    response: *StoredResponse,

    /// Timestamp when entry was added.
    inserted_time: i64,

    const Self = @This();

    pub fn init(allocator: Allocator, request: *StoredRequest, response: *StoredResponse) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .request = request,
            .response = response,
            .inserted_time = std.time.timestamp(),
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.request.deinit();
        self.response.deinit();
        self.allocator.destroy(self);
    }
};

// =============================================================================
// Tests
// =============================================================================

test "StoredRequest.init and deinit" {
    const allocator = std.testing.allocator;

    const headers = [_]HeaderEntry{
        .{ .name = "Content-Type", .value = "application/json" },
    };

    const request = try StoredRequest.init(allocator, "https://example.com/api", "GET", &headers);
    defer request.deinit();

    try std.testing.expectEqualStrings("https://example.com/api", request.url);
    try std.testing.expectEqualStrings("GET", request.method);
    try std.testing.expectEqual(@as(usize, 1), request.headers.len);
}

test "StoredRequest.getHeader" {
    const allocator = std.testing.allocator;

    const headers = [_]HeaderEntry{
        .{ .name = "Content-Type", .value = "application/json" },
        .{ .name = "Accept", .value = "text/html" },
    };

    const request = try StoredRequest.init(allocator, "https://example.com", "GET", &headers);
    defer request.deinit();

    try std.testing.expectEqualStrings("application/json", request.getHeader("Content-Type").?);
    try std.testing.expectEqualStrings("application/json", request.getHeader("content-type").?); // Case insensitive
    try std.testing.expect(request.getHeader("X-Custom") == null);
}

test "StoredResponse.init and deinit" {
    const allocator = std.testing.allocator;

    const headers = [_]HeaderEntry{
        .{ .name = "Content-Type", .value = "text/html" },
    };

    const response = try StoredResponse.init(
        allocator,
        200,
        "OK",
        &headers,
        "<html></html>",
        .basic,
    );
    defer response.deinit();

    try std.testing.expectEqual(@as(u16, 200), response.status);
    try std.testing.expectEqualStrings("OK", response.status_text);
    try std.testing.expect(response.isOk());
    try std.testing.expectEqualStrings("<html></html>", response.body.?);
}

test "StoredResponse.isOk" {
    const allocator = std.testing.allocator;

    const ok_response = try StoredResponse.init(allocator, 200, "OK", &[_]HeaderEntry{}, null, .basic);
    defer ok_response.deinit();
    try std.testing.expect(ok_response.isOk());

    const redirect = try StoredResponse.init(allocator, 301, "Moved", &[_]HeaderEntry{}, null, .basic);
    defer redirect.deinit();
    try std.testing.expect(!redirect.isOk());

    const error_resp = try StoredResponse.init(allocator, 500, "Error", &[_]HeaderEntry{}, null, .basic);
    defer error_resp.deinit();
    try std.testing.expect(!error_resp.isOk());
}

test "CacheEntry.init and deinit" {
    const allocator = std.testing.allocator;

    const request = try StoredRequest.init(allocator, "https://example.com", "GET", &[_]HeaderEntry{});
    const response = try StoredResponse.init(allocator, 200, "OK", &[_]HeaderEntry{}, "body", .basic);

    const entry = try CacheEntry.init(allocator, request, response);
    defer entry.deinit();

    try std.testing.expectEqualStrings("https://example.com", entry.request.url);
    try std.testing.expectEqual(@as(u16, 200), entry.response.status);
}

test "ResponseType.getName" {
    try std.testing.expectEqualStrings("basic", ResponseType.basic.getName());
    try std.testing.expectEqualStrings("cors", ResponseType.cors.getName());
    try std.testing.expectEqualStrings("error", ResponseType.err.getName());
}
