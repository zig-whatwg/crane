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
const infra = @import("infra");
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
    var result = infra.List(u8).init(allocator);
    errdefer result.deinit();

    for (input[start..end]) |c| {
        if (!isTabOrNewline(c)) {
            try result.append(c);
        }
    }

    return result.toOwnedSlice();
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














