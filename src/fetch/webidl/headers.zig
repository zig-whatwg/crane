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

// =============================================================================
// The Headers class's algorithms, over a header list and a guard
// =============================================================================
//
// Every Headers object - `new Headers()`, a Request's or a Response's - is a
// header list with a guard, and its methods and the "fill" its constructors
// run are these. src/webidl/impls/Headers.zig, Request.zig and Response.zig
// call them with the list and guard they hold.

/// HTTP whitespace: U+0009, U+000A, U+000D and U+0020.
const http_whitespace = "\t\n\r ";

/// Fetch "normalize" a byte sequence: remove leading and trailing HTTP
/// whitespace bytes. A slice of `value`.
pub fn normalizeValue(value: []const u8) []const u8 {
    return std.mem.trim(u8, value, http_whitespace);
}

/// Fetch "validate" a header (name, value) for a Headers object with
/// `guard`: an invalid name or value, or any change to an immutable
/// object, throws; a name the guard forbids is false (ignored).
///
/// Spec: https://fetch.spec.whatwg.org/#headers-validate
pub fn validate(guard: HeadersGuard, name: []const u8, value: []const u8) error{TypeError}!bool {
    // 1. If name is not a header name or value is not a header value, then
    //    throw a TypeError.
    if (!validation.isValidHeaderName(name) or !validation.isValidHeaderValue(value)) return error.TypeError;
    switch (guard) {
        // 2. If headers's guard is "immutable", then throw a TypeError.
        .immutable => return error.TypeError,
        // 3. If headers's guard is "request" and (name, value) is a
        //    forbidden request-header, then return false.
        .request => if (validation.isForbiddenRequestHeader(name, value)) return false,
        // 4. If headers's guard is "response" and name is a forbidden
        //    response-header name, then return false.
        .response => if (validation.isForbiddenResponseHeaderName(name)) return false,
        .request_no_cors, .none => {},
    }
    // 5. Return true.
    return true;
}

/// Fetch "append" (name, value) to a Headers object: `list` with `guard`.
///
/// Spec: https://fetch.spec.whatwg.org/#concept-headers-append
pub fn append(allocator: Allocator, list: *HeaderList, guard: HeadersGuard, name: []const u8, raw_value: []const u8) !void {
    // 1. Normalize value.
    const value = normalizeValue(raw_value);
    // 2. If validating (name, value) for headers returns false, then return.
    if (!try validate(guard, name, value)) return;
    // 3. If headers's guard is "request-no-cors":
    if (guard == .request_no_cors) {
        // 1. Let temporaryValue be the result of getting name from headers's
        //    header list.
        const existing = try list.get(allocator, name);
        defer if (existing) |e| allocator.free(e);
        // 2-3. If temporaryValue is null, set it to value; otherwise to
        //      temporaryValue, followed by 0x2C 0x20, followed by value.
        const temporary = if (existing) |e| try std.mem.concat(allocator, u8, &.{ e, ", ", value }) else try allocator.dupe(u8, value);
        defer allocator.free(temporary);
        // 4. If (name, temporaryValue) is not a no-CORS-safelisted
        //    request-header, then return.
        if (!validation.isNoCORSSafelistedRequestHeader(name, temporary)) return;
    }
    // 4. Append (name, value) to headers's header list.
    try list.append(name, value);
    // 5. If headers's guard is "request-no-cors", then remove privileged
    //    no-CORS request-headers from headers.
    if (guard == .request_no_cors) removePrivilegedNoCorsRequestHeaders(list);
}

/// Fetch "set" on a Headers object - Headers.prototype.set's steps.
///
/// Spec: https://fetch.spec.whatwg.org/#dom-headers-set
pub fn set(list: *HeaderList, guard: HeadersGuard, name: []const u8, raw_value: []const u8) !void {
    // 1. Normalize value.
    const value = normalizeValue(raw_value);
    // 2. If validating (name, value) for this returns false, then return.
    if (!try validate(guard, name, value)) return;
    // 3. If this's guard is "request-no-cors" and (name, value) is not a
    //    no-CORS-safelisted request-header, then return.
    if (guard == .request_no_cors and !validation.isNoCORSSafelistedRequestHeader(name, value)) return;
    // 4. Set (name, value) in this's header list.
    try list.set(name, value);
    // 5. If this's guard is "request-no-cors", then remove privileged
    //    no-CORS request-headers from this.
    if (guard == .request_no_cors) removePrivilegedNoCorsRequestHeaders(list);
}

/// Headers.prototype.delete's steps.
///
/// Spec: https://fetch.spec.whatwg.org/#dom-headers-delete
pub fn delete(list: *HeaderList, guard: HeadersGuard, name: []const u8) !void {
    // 1. If validating (name, ``) for this returns false, then return.
    if (!try validate(guard, name, "")) return;
    // 2. If this's guard is "request-no-cors", name is not a
    //    no-CORS-safelisted request-header name, and name is not a
    //    privileged no-CORS request-header name, then return.
    if (guard == .request_no_cors and !validation.isNoCORSSafelistedRequestHeaderName(name) and
        !validation.isPrivilegedNoCORSRequestHeaderName(name)) return;
    // 3. If this's header list does not contain name, then return.
    if (!list.contains(name)) return;
    // 4. Delete name from this's header list.
    list.delete(name);
    // 5. If this's guard is "request-no-cors", then remove privileged
    //    no-CORS request-headers from this.
    if (guard == .request_no_cors) removePrivilegedNoCorsRequestHeaders(list);
}

/// Fetch "fill" a Headers object from a sequence of name-value pairs: each
/// must be exactly a pair, or TypeError.
///
/// Spec: https://fetch.spec.whatwg.org/#concept-headers-fill
pub fn fillFromSequence(allocator: Allocator, list: *HeaderList, guard: HeadersGuard, pairs: []const []const []const u8) !void {
    for (pairs) |header| {
        // 1.1. If header's size is not 2, then throw a TypeError.
        if (header.len != 2) return error.TypeError;
        // 1.2. Append (header[0], header[1]) to headers.
        try append(allocator, list, guard, header[0], header[1]);
    }
}

/// Fetch "remove privileged no-CORS request-headers" from a header list.
pub fn removePrivilegedNoCorsRequestHeaders(list: *HeaderList) void {
    // 1. For each headerName of privileged no-CORS request-header names:
    //    delete headerName from headers's header list. (There is one:
    //    `Range`.)
    list.delete("Range");
}

// The struct's own methods share these names; inside it they reach the
// free functions through these.
const appendTo = append;
const setIn = set;
const deleteFrom = delete;

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
        try appendTo(self.allocator, &self.header_list, self.guard, name, value);
    }

    /// Internal append without validation.
    fn appendInternal(self: *Self, name: []const u8, value: []const u8) !void {
        try self.header_list.append(name, value);
    }

    /// Delete all headers with the given name.
    ///
    /// Spec: delete(name)
    pub fn delete(self: *Self, name: []const u8) !void {
        try deleteFrom(&self.header_list, self.guard, name);
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
        try setIn(&self.header_list, self.guard, name, value);
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

    // "validate" step 2: an immutable Headers object throws a TypeError -
    // it does not ignore the change quietly, as this test used to expect.
    try std.testing.expectError(error.TypeError, headers.append("Content-Type", "text/plain"));

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

test "Headers append: normalizes the value, and each guard decides what it takes" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    // Normalized: leading and trailing HTTP whitespace goes.
    try append(allocator, &list, .none, "Set-Cookie", " \tfoo=bar \r\n");
    const got = (try list.get(allocator, "set-cookie")).?;
    defer allocator.free(got);
    try std.testing.expectEqualStrings("foo=bar", got);

    // An invalid name or value throws, whatever the guard.
    try std.testing.expectError(error.TypeError, append(allocator, &list, .none, "bad name", "x"));
    try std.testing.expectError(error.TypeError, append(allocator, &list, .none, "x", "a\x00b"));
    // An immutable object throws; a forbidden name is quietly left out.
    try std.testing.expectError(error.TypeError, append(allocator, &list, .immutable, "x", "1"));
    try append(allocator, &list, .request, "Host", "a.test");
    try std.testing.expect(!list.contains("Host"));
    try append(allocator, &list, .response, "Set-Cookie2", "x");
    try std.testing.expect(!list.contains("Set-Cookie2"));
}

test "Headers append under request-no-cors: the combined value must stay safelisted, and Range goes" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try append(allocator, &list, .request_no_cors, "Accept", "text/html");
    try std.testing.expect(list.contains("Accept"));
    // A name that is not no-CORS-safelisted is left out.
    try append(allocator, &list, .request_no_cors, "X-Test", "hi");
    try std.testing.expect(!list.contains("X-Test"));
    // Accept's combined value would pass 128 bytes: left out.
    try append(allocator, &list, .request_no_cors, "Accept", "s" ** 128);
    const accept = (try list.get(allocator, "Accept")).?;
    defer allocator.free(accept);
    try std.testing.expectEqualStrings("text/html", accept);
    // Content-Type must stay a safelisted MIME type.
    try append(allocator, &list, .request_no_cors, "Content-Type", "text/html");
    try std.testing.expect(!list.contains("Content-Type"));
}

test "Headers set and delete follow the same guards" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try set(&list, .none, "A", " 1 ");
    const a = (try list.get(allocator, "a")).?;
    defer allocator.free(a);
    try std.testing.expectEqualStrings("1", a);
    try std.testing.expectError(error.TypeError, set(&list, .immutable, "A", "2"));
    try std.testing.expectError(error.TypeError, delete(&list, .immutable, "A"));
    try delete(&list, .none, "A");
    try std.testing.expect(!list.contains("A"));

    // request-no-cors: set only a safelisted pair; delete only a
    // safelisted or privileged name.
    try set(&list, .request_no_cors, "X-Test", "1");
    try std.testing.expect(!list.contains("X-Test"));
    try list.append("X-Other", "1");
    try delete(&list, .request_no_cors, "X-Other");
    try std.testing.expect(list.contains("X-Other"));
}

test "Headers fill from a sequence: every item a pair" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();
    const good = [_][]const []const u8{ &.{ "a", "1" }, &.{ "b", "2" } };
    try fillFromSequence(allocator, &list, .none, &good);
    try std.testing.expect(list.contains("a") and list.contains("b"));
    const bad = [_][]const []const u8{&.{"a"}};
    try std.testing.expectError(error.TypeError, fillFromSequence(allocator, &list, .none, &bad));
}
