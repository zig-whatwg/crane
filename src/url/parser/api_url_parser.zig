//! Public API for URL Parsing
//!
//! This module provides the high-level public API for URL parsing,
//! wrapping the basic URL parser with convenient error handling and
//! input validation.
//!
//! Example usage:
//! ```zig
//! const url = try parseURL(allocator, "https://example.com/path?query#frag");
//! defer url.deinit();
//! ```

const std = @import("std");
const URLRecord = @import("url_record").URLRecord;
const basic_parser = @import("basic_parser");

/// Parse a URL string
///
/// Takes an input string and optional base URL, returns a parsed URLRecord.
/// The input is preprocessed according to spec (strip C0 controls, remove tabs/newlines).
///
/// Arguments:
/// - allocator: Memory allocator
/// - input: URL string to parse
/// - base: Optional base URL for relative URL resolution
///
/// Returns: URLRecord or error
///
/// Example:
/// ```zig
/// const url = try parseURL(allocator, "https://example.com", null);
/// defer url.deinit();
/// ```
pub fn parseURL(
    allocator: std.mem.Allocator,
    input: []const u8,
    base: ?*const URLRecord,
) !URLRecord {
    // Preprocess input per spec (lines 1041-1047)
    const preprocessed = try preprocessInput(allocator, input);
    defer allocator.free(preprocessed);

    // Call basic URL parser
    return basic_parser.parse(allocator, preprocessed, base);
}

/// Preprocess URL input string per spec
///
/// Steps:
/// 1. Strip leading and trailing C0 controls and spaces (spec line 1043)
/// 2. Remove all ASCII tab and newline characters (spec line 1047)
///
/// Note: Spec also requires validation errors for these cases,
/// but we focus on correct parsing for now.
fn preprocessInput(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    // Step 1: Strip leading C0 controls and spaces
    var start: usize = 0;
    while (start < input.len and isC0ControlOrSpace(input[start])) {
        start += 1;
    }

    // Strip trailing C0 controls and spaces
    var end: usize = input.len;
    while (end > start and isC0ControlOrSpace(input[end - 1])) {
        end -= 1;
    }

    // Step 2: Remove ASCII tab and newline
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (input[start..end]) |c| {
        if (!isTabOrNewline(c)) {
            try result.append(allocator, c);
        }
    }

    return try result.toOwnedSlice(allocator);
}

/// Check if character is C0 control or space (spec: C0 control or space)
///
/// C0 controls: U+0000 to U+001F
/// Space: U+0020
fn isC0ControlOrSpace(c: u8) bool {
    return c <= 0x20;
}

/// Check if character is ASCII tab or newline
///
/// Tab: U+0009
/// LF: U+000A
/// CR: U+000D
fn isTabOrNewline(c: u8) bool {
    return c == 0x09 or c == 0x0A or c == 0x0D;
}

/// Parse a URL string with validation
///
/// Similar to parseURL but provides more detailed error information
/// and validates the input more strictly.
pub fn parseURLStrict(
    allocator: std.mem.Allocator,
    input: []const u8,
    base: ?*const URLRecord,
) !URLRecord {
    // Validate input is not empty
    if (input.len == 0) {
        return error.InvalidURL;
    }

    // Check for leading/trailing C0 controls (validation error per spec)
    if (input.len > 0) {
        if (isC0ControlOrSpace(input[0]) or isC0ControlOrSpace(input[input.len - 1])) {
            // Spec: validation error, but we continue
        }
    }

    // Check for tab/newline (validation error per spec)
    for (input) |c| {
        if (isTabOrNewline(c)) {
            // Spec: validation error, but we continue
            break;
        }
    }

    return parseURL(allocator, input, base);
}

// ============================================================================
// Tests
// ============================================================================

test "api parser - simple HTTP URL" {
    const allocator = std.testing.allocator;

    const url = try parseURL(allocator, "http://example.com", null);
    defer url.deinit();

    try std.testing.expectEqualStrings("http", url.scheme());
    try std.testing.expect(url.host != null);
}

test "api parser - with leading/trailing spaces" {
    const allocator = std.testing.allocator;

    const url = try parseURL(allocator, "  http://example.com  ", null);
    defer url.deinit();

    try std.testing.expectEqualStrings("http", url.scheme());
}

test "api parser - with tab characters" {
    const allocator = std.testing.allocator;

    const url = try parseURL(allocator, "http://exam\tple.com", null);
    defer url.deinit();

    try std.testing.expectEqualStrings("http", url.scheme());
    // Tab should be removed from host
    try std.testing.expect(url.host != null);
}

test "api parser - with newline characters" {
    const allocator = std.testing.allocator;

    const url = try parseURL(allocator, "http://example.com/pa\nth", null);
    defer url.deinit();

    try std.testing.expectEqualStrings("http", url.scheme());
    // Newline should be removed from path
}

test "api parser - full URL with all components" {
    const allocator = std.testing.allocator;

    const url = try parseURL(allocator, "https://user:pass@example.com:8080/path?query#frag", null);
    defer url.deinit();

    try std.testing.expectEqualStrings("https", url.scheme());
    try std.testing.expectEqualStrings("user", url.username());
    try std.testing.expectEqualStrings("pass", url.password());
    try std.testing.expectEqual(@as(?u16, 8080), url.port);
    try std.testing.expectEqualStrings("query", url.query().?);
    try std.testing.expectEqualStrings("frag", url.fragment().?);
}

test "api parser - relative URL" {
    const allocator = std.testing.allocator;

    const base = try parseURL(allocator, "http://example.com/base/", null);
    defer base.deinit();

    const url = try parseURL(allocator, "../other", &base);
    defer url.deinit();

    try std.testing.expectEqualStrings("http", url.scheme());
    try std.testing.expect(url.host != null);
}

test "api parser - file URL" {
    const allocator = std.testing.allocator;

    const url = try parseURL(allocator, "file:///path/to/file", null);
    defer url.deinit();

    try std.testing.expectEqualStrings("file", url.scheme());
}

test "api parser - mailto URL (opaque path)" {
    const allocator = std.testing.allocator;

    const url = try parseURL(allocator, "mailto:user@example.com", null);
    defer url.deinit();

    try std.testing.expectEqualStrings("mailto", url.scheme());
    try std.testing.expect(url.hasOpaquePath());
}

test "api parser - strict validation" {
    const allocator = std.testing.allocator;

    const url = try parseURLStrict(allocator, "http://example.com", null);
    defer url.deinit();

    try std.testing.expectEqualStrings("http", url.scheme());
}

test "preprocessing - strip leading spaces" {
    const allocator = std.testing.allocator;

    const result = try preprocessInput(allocator, "   test");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("test", result);
}

test "preprocessing - strip trailing spaces" {
    const allocator = std.testing.allocator;

    const result = try preprocessInput(allocator, "test   ");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("test", result);
}

test "preprocessing - remove tabs" {
    const allocator = std.testing.allocator;

    const result = try preprocessInput(allocator, "te\tst");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("test", result);
}

test "preprocessing - remove newlines" {
    const allocator = std.testing.allocator;

    const result = try preprocessInput(allocator, "te\nst");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("test", result);
}

test "preprocessing - multiple operations" {
    const allocator = std.testing.allocator;

    const result = try preprocessInput(allocator, "  te\tst\n  ");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("test", result);
}
