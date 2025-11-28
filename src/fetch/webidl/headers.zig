//! Headers WebIDL Interface - WHATWG Fetch Specification
//!
//! This module implements the Headers WebIDL interface that wraps
//! the internal header list.
//!
//! Spec: https://fetch.spec.whatwg.org/#headers-class
//!
//! The Headers interface:
//! - Wraps a header list
//! - Has a guard that restricts mutation
//! - Provides iteration over headers

const std = @import("std");
const Allocator = std.mem.Allocator;
const header_list = @import("../internal/header_list.zig");
const HeaderList = header_list.HeaderList;
const Header = header_list.Header;
const guards = @import("../internal/guards.zig");
const HeadersGuard = guards.HeaderGuard;
const validation = @import("../internal/validation.zig");

/// Headers initialization type.
/// Corresponds to WebIDL: sequence<sequence<ByteString>> or record<ByteString, ByteString>
pub const HeadersInit = union(enum) {
    /// Initialize from a sequence of name-value pairs
    sequence: []const [2][]const u8,
    /// Initialize from a Headers object
    headers: *const Headers,
    /// Initialize from nothing (empty)
    none,
};

/// Headers class per WebIDL.
///
/// Spec: https://fetch.spec.whatwg.org/#headers-class
pub const Headers = struct {
    allocator: Allocator,
    /// The underlying header list
    header_list: HeaderList,
    /// Guard restricting mutation
    guard: HeadersGuard,

    const Self = @This();

    /// Create a new Headers object.
    ///
    /// Spec constructor: new Headers(init)
    pub fn init(allocator: Allocator, headers_init: HeadersInit) !*Self {
        const headers = try allocator.create(Self);
        errdefer allocator.destroy(headers);

        headers.* = .{
            .allocator = allocator,
            .header_list = HeaderList.init(allocator),
            .guard = .none,
        };

        // Fill with init data
        switch (headers_init) {
            .sequence => |seq| {
                for (seq) |pair| {
                    try headers.appendInternal(pair[0], pair[1]);
                }
            },
            .headers => |other| {
                // Copy from other Headers
                for (other.header_list.entries.items) |entry| {
                    try headers.appendInternal(entry.name, entry.value);
                }
            },
            .none => {},
        }

        return headers;
    }

    /// Create Headers with a specific guard.
    pub fn initWithGuard(allocator: Allocator, guard: HeadersGuard) !*Self {
        const headers = try allocator.create(Self);
        headers.* = .{
            .allocator = allocator,
            .header_list = HeaderList.init(allocator),
            .guard = guard,
        };
        return headers;
    }

    /// Deinitialize the Headers object.
    pub fn deinit(self: *Self) void {
        self.header_list.deinit();
        self.allocator.destroy(self);
    }

    /// Append a header.
    ///
    /// Spec: append(name, value)
    pub fn append(self: *Self, name: []const u8, value: []const u8) !void {
        // Validate name and value
        if (!validation.isValidHeaderName(name)) {
            return error.TypeError;
        }
        if (!validation.isValidHeaderValue(value)) {
            return error.TypeError;
        }

        // Check guard
        if (!self.canMutate(name)) {
            return; // Silently fail per spec
        }

        try self.appendInternal(name, value);
    }

    /// Internal append without validation.
    fn appendInternal(self: *Self, name: []const u8, value: []const u8) !void {
        try self.header_list.append(name, value);
    }

    /// Delete all headers with the given name.
    ///
    /// Spec: delete(name)
    pub fn delete(self: *Self, name: []const u8) !void {
        if (!validation.isValidHeaderName(name)) {
            return error.TypeError;
        }

        if (!self.canMutate(name)) {
            return;
        }

        self.header_list.delete(name);
    }

    /// Get the combined value of headers with the given name.
    ///
    /// Spec: get(name)
    /// Returns null if no header exists.
    pub fn get(self: *const Self, allocator: Allocator, name: []const u8) !?[]const u8 {
        if (!validation.isValidHeaderName(name)) {
            return error.TypeError;
        }
        return try self.header_list.get(allocator, name);
    }

    /// Get all Set-Cookie header values.
    ///
    /// Spec: getSetCookie()
    pub fn getSetCookie(self: *const Self, allocator: Allocator) ![]const []const u8 {
        return try self.header_list.getSetCookie(allocator);
    }

    /// Check if a header with the given name exists.
    ///
    /// Spec: has(name)
    pub fn has(self: *const Self, name: []const u8) !bool {
        if (!validation.isValidHeaderName(name)) {
            return error.TypeError;
        }
        return self.header_list.contains(name);
    }

    /// Set a header, replacing any existing headers with the same name.
    ///
    /// Spec: set(name, value)
    pub fn set(self: *Self, name: []const u8, value: []const u8) !void {
        if (!validation.isValidHeaderName(name)) {
            return error.TypeError;
        }
        if (!validation.isValidHeaderValue(value)) {
            return error.TypeError;
        }

        if (!self.canMutate(name)) {
            return;
        }

        try self.header_list.set(name, value);
    }

    /// Check if mutation is allowed for this header name.
    fn canMutate(self: *const Self, name: []const u8) bool {
        return switch (self.guard) {
            .immutable => false,
            .request => !validation.isForbiddenRequestHeader(name, ""),
            .request_no_cors => !validation.isForbiddenRequestHeader(name, "") and
                validation.isNoCORSSafelistedRequestHeaderName(name),
            .response => !validation.isForbiddenResponseHeaderName(name),
            .none => true,
        };
    }

    // === Iteration ===

    /// Iterator for Headers.
    pub const Iterator = struct {
        headers: *const Headers,
        index: usize,
        sorted_entries: ?[]Header,
        allocator: Allocator,

        pub fn next(self: *Iterator) ?Header {
            // Lazy sort on first access
            if (self.sorted_entries == null) {
                self.sorted_entries = self.sortEntries() catch return null;
            }

            const entries = self.sorted_entries orelse return null;
            if (self.index >= entries.len) {
                return null;
            }

            const entry = entries[self.index];
            self.index += 1;
            return entry;
        }

        fn sortEntries(self: *Iterator) ![]Header {
            // Per spec: sort by name (byte-wise ascending)
            const entries = try self.allocator.alloc(Header, self.headers.header_list.entries.items.len);
            @memcpy(entries, self.headers.header_list.entries.items);

            std.mem.sort(Header, entries, {}, struct {
                fn lessThan(_: void, a: Header, b: Header) bool {
                    return std.mem.lessThan(u8, std.ascii.lowerString(
                        @constCast(a.name[0..@min(a.name.len, 256)]),
                        a.name,
                    ), std.ascii.lowerString(
                        @constCast(b.name[0..@min(b.name.len, 256)]),
                        b.name,
                    ));
                }
            }.lessThan);

            return entries;
        }

        pub fn deinit(self: *Iterator) void {
            if (self.sorted_entries) |entries| {
                self.allocator.free(entries);
            }
        }
    };

    /// Get an iterator over the headers.
    pub fn iterator(self: *const Self, allocator: Allocator) Iterator {
        return .{
            .headers = self,
            .index = 0,
            .sorted_entries = null,
            .allocator = allocator,
        };
    }

    /// Get number of headers.
    pub fn len(self: *const Self) usize {
        return self.header_list.entries.items.len;
    }

    /// Clone this Headers object.
    pub fn clone(self: *const Self, allocator: Allocator) !*Self {
        const new_headers = try allocator.create(Self);
        errdefer allocator.destroy(new_headers);

        new_headers.* = .{
            .allocator = allocator,
            .header_list = try self.header_list.clone(allocator),
            .guard = self.guard,
        };

        return new_headers;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "Headers.init empty" {
    const allocator = std.testing.allocator;

    const headers = try Headers.init(allocator, .none);
    defer headers.deinit();

    try std.testing.expectEqual(@as(usize, 0), headers.len());
}

test "Headers.init from sequence" {
    const allocator = std.testing.allocator;

    const init_data = [_][2][]const u8{
        .{ "Content-Type", "text/plain" },
        .{ "Accept", "application/json" },
    };

    const headers = try Headers.init(allocator, .{ .sequence = &init_data });
    defer headers.deinit();

    try std.testing.expectEqual(@as(usize, 2), headers.len());
    try std.testing.expect(try headers.has("Content-Type"));
    try std.testing.expect(try headers.has("Accept"));
}

test "Headers.append and get" {
    const allocator = std.testing.allocator;

    const headers = try Headers.init(allocator, .none);
    defer headers.deinit();

    try headers.append("Content-Type", "text/plain");

    const value = try headers.get(allocator, "Content-Type");
    defer if (value) |v| allocator.free(v);

    try std.testing.expectEqualStrings("text/plain", value.?);
}

test "Headers.append combines values" {
    const allocator = std.testing.allocator;

    const headers = try Headers.init(allocator, .none);
    defer headers.deinit();

    try headers.append("Accept", "text/html");
    try headers.append("Accept", "application/json");

    const value = try headers.get(allocator, "Accept");
    defer if (value) |v| allocator.free(v);

    try std.testing.expectEqualStrings("text/html, application/json", value.?);
}

test "Headers.set replaces" {
    const allocator = std.testing.allocator;

    const headers = try Headers.init(allocator, .none);
    defer headers.deinit();

    try headers.append("Content-Type", "text/html");
    try headers.set("Content-Type", "application/json");

    const value = try headers.get(allocator, "Content-Type");
    defer if (value) |v| allocator.free(v);

    try std.testing.expectEqualStrings("application/json", value.?);
}

test "Headers.delete" {
    const allocator = std.testing.allocator;

    const headers = try Headers.init(allocator, .none);
    defer headers.deinit();

    try headers.append("Content-Type", "text/plain");
    try headers.append("Accept", "application/json");

    try std.testing.expect(try headers.has("Content-Type"));

    try headers.delete("Content-Type");

    try std.testing.expect(!(try headers.has("Content-Type")));
    try std.testing.expect(try headers.has("Accept"));
}

test "Headers.has case insensitive" {
    const allocator = std.testing.allocator;

    const headers = try Headers.init(allocator, .none);
    defer headers.deinit();

    try headers.append("Content-Type", "text/plain");

    try std.testing.expect(try headers.has("content-type"));
    try std.testing.expect(try headers.has("CONTENT-TYPE"));
    try std.testing.expect(try headers.has("Content-Type"));
}

test "Headers.guard immutable blocks mutation" {
    const allocator = std.testing.allocator;

    const headers = try Headers.initWithGuard(allocator, .immutable);
    defer headers.deinit();

    // Should silently fail
    try headers.append("Content-Type", "text/plain");

    try std.testing.expectEqual(@as(usize, 0), headers.len());
}

test "Headers.clone" {
    const allocator = std.testing.allocator;

    const original = try Headers.init(allocator, .none);
    defer original.deinit();

    try original.append("Content-Type", "text/plain");

    const cloned = try original.clone(allocator);
    defer cloned.deinit();

    try std.testing.expect(try cloned.has("Content-Type"));

    // Modify original doesn't affect clone
    try original.delete("Content-Type");
    try std.testing.expect(try cloned.has("Content-Type"));
}
