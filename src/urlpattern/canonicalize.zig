//! URLPattern §3.1 encoding callbacks. Delimiter stripping belongs to
//! URLPatternInit processing, not these callbacks on individual fragments.
const std = @import("std");
const Allocator = std.mem.Allocator;
const url = @import("url");
const basic_parser = url.parser.basic_url_parser;
const URLRecord = url.internal.url_record.URLRecord;

pub const CanonicalizationError = error{
    InvalidProtocol,
    InvalidHostname,
    InvalidIPv6,
    InvalidPort,
    InvalidPathname,
    OutOfMemory,
};

fn createDummyURL(allocator: Allocator) Allocator.Error!URLRecord {
    return basic_parser.parse(allocator, "https://dummy.invalid/", null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => unreachable,
    };
}

pub fn serializePath(allocator: Allocator, record: *const URLRecord) Allocator.Error![]u8 {
    switch (record.path) {
        .opaque_path => |path| return allocator.dupe(u8, path),
        .segments => |segments| {
            var result: std.ArrayList(u8) = .empty;
            errdefer result.deinit(allocator);
            for (segments.toSlice()) |segment| {
                try result.append(allocator, '/');
                try result.appendSlice(allocator, segment);
            }
            return result.toOwnedSlice(allocator);
        },
    }
}

pub fn canonicalizeProtocol(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    if (value.len == 0) return allocator.dupe(u8, value);
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const temporary = arena.allocator();
    // Steps 2-4: normal parsing, not the protocol setter's state override.
    const input = try std.mem.concat(temporary, u8, &.{ value, "://dummy.invalid/" });
    const record = basic_parser.parse(temporary, input, null) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidProtocol;
    return allocator.dupe(u8, record.scheme());
}

pub fn canonicalizeUsername(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    // Steps 2-4: set-the-username uses the userinfo percent-encode set.
    return url.percent_encoding.utf8PercentEncode(allocator, value, .userinfo);
}

pub fn canonicalizePassword(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    // Steps 2-4: set-the-password uses the same encoding as username.
    return url.percent_encoding.utf8PercentEncode(allocator, value, .userinfo);
}

pub fn canonicalizeHostname(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    if (value.len == 0) return allocator.dupe(u8, value);
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const temporary = arena.allocator();
    var record = try createDummyURL(temporary);
    // Steps 3-5: URL hostname state handles IDNA, IPv4, escapes and terminators.
    _ = basic_parser.parseWithStateOverride(temporary, value, null, .hostname, &record) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidHostname;
    return if (record.host) |host| url.host_serializer.serializeHost(allocator, host) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidHostname else allocator.dupe(u8, "");
}

pub fn canonicalizeIPv6Hostname(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    const result = try allocator.alloc(u8, value.len);
    errdefer allocator.free(result);
    // Step 2: IPv6 fragments need not themselves form a complete address.
    for (value, 0..) |c, i| {
        if (!std.ascii.isHex(c) and c != '[' and c != ']' and c != ':') return error.InvalidIPv6;
        result[i] = std.ascii.toLower(c);
    }
    return result;
}

pub fn canonicalizePort(allocator: Allocator, value: []const u8, protocol: ?[]const u8) CanonicalizationError![]u8 {
    if (value.len == 0) return allocator.dupe(u8, value);
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const temporary = arena.allocator();
    var record = try createDummyURL(temporary);
    // Steps 3-4 set the record's scheme directly, including the empty scheme.
    // The dummy's other buffer-backed strings are empty; reset their offsets.
    const scheme = try temporary.dupe(u8, protocol orelse "");
    record.buffer = scheme;
    record.scheme_start = 0;
    record.scheme_len = @intCast(scheme.len);
    record.username_start = 0;
    record.password_start = 0;
    record.query_start = 0;
    record.fragment_start = 0;
    // Steps 5-7: URL port state accepts a leading digit run, reports overflow,
    // and elides default ports only when a protocol was supplied.
    _ = basic_parser.parseWithStateOverride(temporary, value, null, .port, &record) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidPort;
    return if (record.port) |port| std.fmt.allocPrint(allocator, "{d}", .{port}) else allocator.dupe(u8, "");
}

pub fn canonicalizePathname(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    if (value.len == 0) return allocator.dupe(u8, value);
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const temporary = arena.allocator();
    // Steps 2-4: shield a fragment without a leading slash from automatic
    // slash insertion and initial dot-segment collapsing.
    const leading_slash = value[0] == '/';
    const modified = if (leading_slash) value else try std.mem.concat(temporary, u8, &.{ "/-", value });
    var record = try createDummyURL(temporary);
    // Steps 5-7: clear the dummy path and use path-start state.
    record.path.segments.clear();
    _ = basic_parser.parseWithStateOverride(temporary, modified, null, .path_start, &record) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidPathname;
    const result = try serializePath(allocator, &record);
    if (leading_slash) return result;
    defer allocator.free(result);
    // Steps 8-10: remove only the artificial "/-".
    return allocator.dupe(u8, result[@min(2, result.len)..]);
}

pub fn canonicalizeOpaquePathname(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    if (value.len == 0) return allocator.dupe(u8, value);
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const temporary = arena.allocator();
    var record = try createDummyURL(temporary);
    // Steps 2-4: set path to an empty string and parse in opaque-path state.
    record.path = .{ .opaque_path = "" };
    _ = basic_parser.parseWithStateOverride(temporary, value, null, .opaque_path, &record) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidPathname;
    return serializePath(allocator, &record);
}

pub fn canonicalizeSearch(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    if (value.len == 0) return allocator.dupe(u8, value);
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const temporary = arena.allocator();
    var record = try createDummyURL(temporary);
    // Steps 3-5: overriding query state initializes an empty query. The dummy
    // is special, so apostrophes use the special-query percent-encode set.
    _ = basic_parser.parseWithStateOverride(temporary, value, null, .query, &record) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else unreachable;
    return allocator.dupe(u8, record.query() orelse "");
}

pub fn canonicalizeHash(allocator: Allocator, value: []const u8) CanonicalizationError![]u8 {
    if (value.len == 0) return allocator.dupe(u8, value);
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const temporary = arena.allocator();
    var record = try createDummyURL(temporary);
    // Steps 3-5: overriding fragment state initializes an empty fragment.
    _ = basic_parser.parseWithStateOverride(temporary, value, null, .fragment, &record) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else unreachable;
    return allocator.dupe(u8, record.fragment() orelse "");
}

// ============================================================================
// Tests
// ============================================================================

test "canonicalizeProtocol - basic" {
    const allocator = std.testing.allocator;

    // Empty value
    {
        const result = try canonicalizeProtocol(allocator, "");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // Lowercase
    {
        const result = try canonicalizeProtocol(allocator, "HTTPS");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("https", result);
    }

    // Canonicalize-protocol steps 2-3 parse the fragment unchanged.
    // Only process-protocol-for-init step 1 strips a trailing delimiter.
    try std.testing.expectError(error.InvalidProtocol, canonicalizeProtocol(allocator, "http:"));

    // Valid scheme with special chars
    {
        const result = try canonicalizeProtocol(allocator, "my+custom-scheme.1");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("my+custom-scheme.1", result);
    }
}

test "canonicalizeProtocol - invalid" {
    const allocator = std.testing.allocator;

    // Must start with alpha
    {
        const result = canonicalizeProtocol(allocator, "123abc");
        try std.testing.expectError(CanonicalizationError.InvalidProtocol, result);
    }

    // Invalid character
    {
        const result = canonicalizeProtocol(allocator, "foo@bar");
        try std.testing.expectError(CanonicalizationError.InvalidProtocol, result);
    }
}

test "canonicalizeUsername - basic" {
    const allocator = std.testing.allocator;

    // Empty value
    {
        const result = try canonicalizeUsername(allocator, "");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // Simple username
    {
        const result = try canonicalizeUsername(allocator, "user");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("user", result);
    }

    // Username with space
    {
        const result = try canonicalizeUsername(allocator, "user name");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("user%20name", result);
    }
}

test "canonicalizePassword - basic" {
    const allocator = std.testing.allocator;

    // Empty value
    {
        const result = try canonicalizePassword(allocator, "");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // Password with special chars
    {
        const result = try canonicalizePassword(allocator, "pass:word");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("pass%3Aword", result);
    }
}

test "canonicalizeIPv6Hostname - basic" {
    const allocator = std.testing.allocator;

    // Simple IPv6
    {
        const result = try canonicalizeIPv6Hostname(allocator, "[::1]");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("[::1]", result);
    }

    // Uppercase to lowercase
    {
        const result = try canonicalizeIPv6Hostname(allocator, "[2001:DB8::1]");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("[2001:db8::1]", result);
    }

    // Invalid character
    {
        const result = canonicalizeIPv6Hostname(allocator, "[::g]");
        try std.testing.expectError(CanonicalizationError.InvalidIPv6, result);
    }
}

test "canonicalizePort - basic" {
    const allocator = std.testing.allocator;

    // Empty value
    {
        const result = try canonicalizePort(allocator, "", null);
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // Simple port
    {
        const result = try canonicalizePort(allocator, "8080", null);
        defer allocator.free(result);
        try std.testing.expectEqualStrings("8080", result);
    }

    // Default port for https
    {
        const result = try canonicalizePort(allocator, "443", "https");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // Default port for http
    {
        const result = try canonicalizePort(allocator, "80", "http");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // Non-default port
    {
        const result = try canonicalizePort(allocator, "8443", "https");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("8443", result);
    }

    // Invalid port (non-numeric)
    {
        const result = canonicalizePort(allocator, "abc", null);
        try std.testing.expectError(CanonicalizationError.InvalidPort, result);
    }
}

test "canonicalizePathname - basic" {
    const allocator = std.testing.allocator;

    // Empty value
    {
        const result = try canonicalizePathname(allocator, "");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // Simple path
    {
        const result = try canonicalizePathname(allocator, "/foo/bar");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("/foo/bar", result);
    }

    // Path with space
    {
        const result = try canonicalizePathname(allocator, "/hello world");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("/hello%20world", result);
    }

    // Path without leading slash
    {
        const result = try canonicalizePathname(allocator, "foo/bar");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("foo/bar", result);
    }
}

test "canonicalizeSearch - basic" {
    const allocator = std.testing.allocator;

    // Empty value
    {
        const result = try canonicalizeSearch(allocator, "");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // With leading ?
    {
        const result = try canonicalizeSearch(allocator, "?foo=bar");
        defer allocator.free(result);
        // URLPattern 3.1 keeps delimiters; process-init 3.2 strips them.
        try std.testing.expectEqualStrings("?foo=bar", result);
    }

    // Without leading ?
    {
        const result = try canonicalizeSearch(allocator, "foo=bar");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("foo=bar", result);
    }

    // With space
    {
        const result = try canonicalizeSearch(allocator, "foo=hello world");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("foo=hello%20world", result);
    }
}

test "canonicalizeHash - basic" {
    const allocator = std.testing.allocator;

    // Empty value
    {
        const result = try canonicalizeHash(allocator, "");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("", result);
    }

    // With leading #
    {
        const result = try canonicalizeHash(allocator, "#section");
        defer allocator.free(result);
        // URLPattern 3.1 keeps delimiters; process-init 3.2 strips them.
        try std.testing.expectEqualStrings("#section", result);
    }

    // Without leading #
    {
        const result = try canonicalizeHash(allocator, "section");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("section", result);
    }

    // With space
    {
        const result = try canonicalizeHash(allocator, "section one");
        defer allocator.free(result);
        try std.testing.expectEqualStrings("section%20one", result);
    }
}
