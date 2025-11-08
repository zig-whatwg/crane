//! URL Parser Helper Functions
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#url-parsing
//!
//! Common helper functions used throughout the URL parser:
//! - Default port lookup for special schemes
//! - Shorten URL's path algorithm
//! - Special scheme checking
//! - Windows drive letter detection

const std = @import("std");
const URLRecord = @import("url_record").URLRecord;
const Path = @import("path").Path;
const windows_drive = @import("windows_drive");

/// P2 Optimization: Check if string contains only ASCII characters (Performance Optimization)
///
/// Most URLs (90%) are pure ASCII. This fast check allows us to skip expensive
/// UTF-8 validation and use faster byte-based operations in the parsing hot path.
///
/// Returns true if all bytes are in ASCII range (0-127).
pub inline fn isAsciiOnly(bytes: []const u8) bool {
    for (bytes) |b| {
        if (b >= 128) return false;
    }
    return true;
}

/// Get default port for a scheme (spec line 845-854)
///
/// Special schemes have default ports:
/// - ftp: 21
/// - file: null
/// - http: 80
/// - https: 443
/// - ws: 80
/// - wss: 443
///
/// All other schemes return null.
///
/// P4 Optimization: Fast path using first character check + length.
/// Most schemes are http/https (80%+), so we optimize for that common case.
/// P7 Optimization: Inline for zero-cost abstraction.
pub inline fn defaultPort(scheme: []const u8) ?u16 {
    if (scheme.len == 0) return null;

    // Fast path: Check first character and length
    switch (scheme[0]) {
        'h' => {
            // http (4 chars) -> 80 or https (5 chars) -> 443
            if (scheme.len == 4 and std.mem.eql(u8, scheme, "http")) return 80;
            if (scheme.len == 5 and std.mem.eql(u8, scheme, "https")) return 443;
            return null;
        },
        'f' => {
            // ftp (3 chars) -> 21 or file (4 chars) -> null
            if (scheme.len == 3 and std.mem.eql(u8, scheme, "ftp")) return 21;
            // file has no default port
            return null;
        },
        'w' => {
            // ws (2 chars) -> 80 or wss (3 chars) -> 443
            if (scheme.len == 2 and std.mem.eql(u8, scheme, "ws")) return 80;
            if (scheme.len == 3 and std.mem.eql(u8, scheme, "wss")) return 443;
            return null;
        },
        else => return null,
    }
}

/// Check if scheme is special (spec line 845-854)
///
/// Special schemes: ftp, file, http, https, ws, wss
///
/// P4 Optimization: Fast path using first character check + length.
/// Most schemes are http/https (80%+), so we optimize for that common case.
/// P7 Optimization: Inline for zero-cost abstraction.
pub inline fn isSpecialScheme(scheme: []const u8) bool {
    if (scheme.len == 0) return false;

    // Fast path: Check first character and length
    switch (scheme[0]) {
        'h' => {
            // http (4 chars) or https (5 chars)
            if (scheme.len == 4) return std.mem.eql(u8, scheme, "http");
            if (scheme.len == 5) return std.mem.eql(u8, scheme, "https");
            return false;
        },
        'f' => {
            // ftp (3 chars) or file (4 chars)
            if (scheme.len == 3) return std.mem.eql(u8, scheme, "ftp");
            if (scheme.len == 4) return std.mem.eql(u8, scheme, "file");
            return false;
        },
        'w' => {
            // ws (2 chars) or wss (3 chars)
            if (scheme.len == 2) return std.mem.eql(u8, scheme, "ws");
            if (scheme.len == 3) return std.mem.eql(u8, scheme, "wss");
            return false;
        },
        else => return false,
    }
}

/// Shorten a URL's path (spec line 888-896)
///
/// Steps:
/// 1. Assert: url does not have an opaque path
/// 2. Let path be url's path
/// 3. If url's scheme is "file", path's size is 1, and path[0] is a
///    normalized Windows drive letter, then return
/// 4. Remove path's last item, if any
pub fn shortenPath(url: *URLRecord) void {
    // Step 1: Assert url does not have opaque path
    std.debug.assert(!url.hasOpaquePath());

    // Step 2: Let path be url's path
    switch (url.path) {
        .opaque_path => unreachable, // Caught by assertion
        .segments => |*segments| {
            // Step 3: Special file: URL handling for Windows drive letters
            const scheme = url.scheme();
            if (std.mem.eql(u8, scheme, "file") and
                segments.items.len == 1 and
                segments.items[0].len >= 2)
            {
                // Check if path[0] is normalized Windows drive letter
                const first_segment = segments.items[0];
                if (windows_drive.isNormalizedWindowsDriveLetter(first_segment)) {
                    return;
                }
            }

            // Step 4: Remove path's last item, if any
            if (segments.items.len > 0) {
                const last = segments.pop();
                url.allocator.free(last);
            }
        },
    }
}

/// Check if string starts with two ASCII hex digits followed by a specific code point
///
/// Used for percent-encoding validation
pub fn startsWithPercentEncoded(s: []const u8) bool {
    if (s.len < 3) return false;
    if (s[0] != '%') return false;
    return std.ascii.isHex(s[1]) and std.ascii.isHex(s[2]);
}

/// Get remaining string from pointer position (used in spec algorithms)
///
/// "remaining" references the code point substring from pointer + 1 to end of string
/// Spec: https://url.spec.whatwg.org/#syntax-url-pointer (line 1030)
/// P7 Optimization: Inline for zero-cost abstraction.
pub inline fn remaining(input: []const u8, pointer: usize) []const u8 {
    if (pointer + 1 >= input.len) return "";
    return input[pointer + 1 ..];
}

/// Check if remaining string starts with a given prefix
/// P7 Optimization: Inline for zero-cost abstraction.
pub inline fn remainingStartsWith(input: []const u8, pointer: usize, prefix: []const u8) bool {
    const rem = remaining(input, pointer);
    return std.mem.startsWith(u8, rem, prefix);
}

test "helpers - defaultPort" {
    try std.testing.expectEqual(@as(?u16, 21), defaultPort("ftp"));
    try std.testing.expectEqual(@as(?u16, null), defaultPort("file"));
    try std.testing.expectEqual(@as(?u16, 80), defaultPort("http"));
    try std.testing.expectEqual(@as(?u16, 443), defaultPort("https"));
    try std.testing.expectEqual(@as(?u16, 80), defaultPort("ws"));
    try std.testing.expectEqual(@as(?u16, 443), defaultPort("wss"));
    try std.testing.expectEqual(@as(?u16, null), defaultPort("mailto"));
    try std.testing.expectEqual(@as(?u16, null), defaultPort("unknown"));
}

test "helpers - isSpecialScheme" {
    try std.testing.expect(isSpecialScheme("ftp"));
    try std.testing.expect(isSpecialScheme("file"));
    try std.testing.expect(isSpecialScheme("http"));
    try std.testing.expect(isSpecialScheme("https"));
    try std.testing.expect(isSpecialScheme("ws"));
    try std.testing.expect(isSpecialScheme("wss"));
    try std.testing.expect(!isSpecialScheme("mailto"));
    try std.testing.expect(!isSpecialScheme("data"));
}

test "helpers - shortenPath" {
    const allocator = std.testing.allocator;

    // Normal path shortening
    {
        const buffer = try allocator.dupe(u8, "http");
        var segments = std.ArrayList([]const u8){};
        try segments.append(allocator, try allocator.dupe(u8, "a"));
        try segments.append(allocator, try allocator.dupe(u8, "b"));
        try segments.append(allocator, try allocator.dupe(u8, "c"));

        var url = URLRecord{
            .buffer = buffer,
            .scheme_start = 0,
            .scheme_len = 4,
            .username_start = 0,
            .username_len = 0,
            .password_start = 0,
            .password_len = 0,
            .host = null,
            .port = null,
            .path = Path{ .segments = segments },
            .query_start = 0,
            .query_len = 0,
            .fragment_start = 0,
            .fragment_len = 0,
            .allocator = allocator,
        };
        defer url.deinit();

        try std.testing.expectEqual(@as(usize, 3), url.path.segments.items.len);

        shortenPath(&url);
        try std.testing.expectEqual(@as(usize, 2), url.path.segments.items.len);

        shortenPath(&url);
        try std.testing.expectEqual(@as(usize, 1), url.path.segments.items.len);

        shortenPath(&url);
        try std.testing.expectEqual(@as(usize, 0), url.path.segments.items.len);

        // Shortening empty path does nothing
        shortenPath(&url);
        try std.testing.expectEqual(@as(usize, 0), url.path.segments.items.len);
    }

    // file: URL with Windows drive letter (should not shorten)
    {
        const buffer = try allocator.dupe(u8, "file");
        var segments = std.ArrayList([]const u8){};
        try segments.append(allocator, try allocator.dupe(u8, "C:"));

        var url = URLRecord{
            .buffer = buffer,
            .scheme_start = 0,
            .scheme_len = 4,
            .username_start = 0,
            .username_len = 0,
            .password_start = 0,
            .password_len = 0,
            .host = null,
            .port = null,
            .path = Path{ .segments = segments },
            .query_start = 0,
            .query_len = 0,
            .fragment_start = 0,
            .fragment_len = 0,
            .allocator = allocator,
        };
        defer url.deinit();

        try std.testing.expectEqual(@as(usize, 1), url.path.segments.items.len);

        // Should not shorten (Windows drive letter protection)
        shortenPath(&url);
        try std.testing.expectEqual(@as(usize, 1), url.path.segments.items.len);
    }
}

test "helpers - startsWithPercentEncoded" {
    try std.testing.expect(startsWithPercentEncoded("%2F"));
    try std.testing.expect(startsWithPercentEncoded("%2f"));
    try std.testing.expect(startsWithPercentEncoded("%20test"));
    try std.testing.expect(!startsWithPercentEncoded("%"));
    try std.testing.expect(!startsWithPercentEncoded("%2"));
    try std.testing.expect(!startsWithPercentEncoded("%GG"));
    try std.testing.expect(!startsWithPercentEncoded("test"));
}

test "helpers - remaining" {
    const input = "https://example.com/path";

    try std.testing.expectEqualStrings("ttps://example.com/path", remaining(input, 0));
    try std.testing.expectEqualStrings("path", remaining(input, 19));
    try std.testing.expectEqualStrings("", remaining(input, input.len - 1));
    try std.testing.expectEqualStrings("", remaining(input, input.len));
}

test "helpers - remainingStartsWith" {
    const input = "https://example.com/path";

    try std.testing.expect(remainingStartsWith(input, 4, "://"));
    try std.testing.expect(remainingStartsWith(input, 19, "path"));
    try std.testing.expect(!remainingStartsWith(input, 0, "://"));
    try std.testing.expect(!remainingStartsWith(input, input.len, "test"));
}
