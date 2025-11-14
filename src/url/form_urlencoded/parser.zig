//! application/x-www-form-urlencoded Parser
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#urlencoded-parsing
//! Spec Reference: Lines 1673-1701
//!
//! The application/x-www-form-urlencoded format is used for encoding
//! name-value pairs in URL query strings and HTML form submissions.

const std = @import("std");
const infra = @import("infra");
const percentDecode = @import("percent_encoding").percentDecode;

/// A name-value tuple (spec line 1686)
pub const Tuple = struct {
    name: []const u8,
    value: []const u8,

    pub fn deinit(self: Tuple, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.value);
    }
};

/// application/x-www-form-urlencoded parsing (spec lines 1673-1701)
///
/// Takes a byte sequence input and returns a list of name-value tuples.
///
/// Steps:
/// 1. Split input on 0x26 (&)
/// 2. Create empty output list
/// 3. For each byte sequence:
///    - Skip if empty
///    - Split on 0x3D (=) to get name and value
///    - Replace 0x2B (+) with 0x20 (space)
///    - Percent-decode and UTF-8 decode
///    - Append tuple to output
/// 4. Return output
///
/// Example:
/// ```
/// "key1=value1&key2=value2" → [("key1", "value1"), ("key2", "value2")]
/// "a=b+c" → [("a", "b c")]  // + becomes space
/// ```
pub fn parse(allocator: std.mem.Allocator, input: []const u8) ![]Tuple {
    // Step 1: Split on 0x26 (&)
    var sequences = std.mem.splitSequence(u8, input, "&");

    // Step 2: Create output list
    var output = infra.List(Tuple).init(allocator);
    errdefer {
        for (output.toSlice()) |tuple| {
            tuple.deinit(allocator);
        }
        output.deinit();
    }

    // Step 3: For each byte sequence
    while (sequences.next()) |bytes| {
        // Step 3.1: Skip if empty
        if (bytes.len == 0) continue;

        var name: []const u8 = undefined;
        var value: []const u8 = undefined;

        // Step 3.2: Split on 0x3D (=)
        if (std.mem.indexOfScalar(u8, bytes, '=')) |eq_pos| {
            name = bytes[0..eq_pos];
            value = bytes[eq_pos + 1 ..];
        } else {
            // Step 3.3: No '=', entire bytes is name, value is empty
            name = bytes;
            value = "";
        }

        // Step 3.4: Replace 0x2B (+) with 0x20 (space)
        const name_with_spaces = try replacePlus(allocator, name);
        defer allocator.free(name_with_spaces);

        const value_with_spaces = try replacePlus(allocator, value);
        defer allocator.free(value_with_spaces);

        // Step 3.5: Percent-decode
        const name_decoded_bytes = try percentDecode(allocator, name_with_spaces);
        defer allocator.free(name_decoded_bytes);

        const value_decoded_bytes = try percentDecode(allocator, value_with_spaces);
        defer allocator.free(value_decoded_bytes);

        // UTF-8 decode (validate it's valid UTF-8)
        const name_string = try validateUtf8AndDupe(allocator, name_decoded_bytes);
        errdefer allocator.free(name_string);

        const value_string = try validateUtf8AndDupe(allocator, value_decoded_bytes);
        errdefer allocator.free(value_string);

        // Step 3.6: Append tuple
        try output.append(.{
            .name = name_string,
            .value = value_string,
        });
    }

    // Step 4: Return output
    return output.toOwnedSlice();
}

/// Replace 0x2B (+) with 0x20 (space) per spec line 1695
fn replacePlus(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result = try allocator.alloc(u8, input.len);
    errdefer allocator.free(result);

    for (input, 0..) |byte, i| {
        result[i] = if (byte == '+') ' ' else byte;
    }

    return result;
}

/// Validate UTF-8 and duplicate string
fn validateUtf8AndDupe(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    // Validate it's valid UTF-8
    if (!std.unicode.utf8ValidateSlice(bytes)) {
        return error.InvalidUtf8;
    }

    return try allocator.dupe(u8, bytes);
}

/// application/x-www-form-urlencoded string parser (spec line 1729)
///
/// Takes a scalar value string, UTF-8 encodes it, and parses it.
pub fn parseString(allocator: std.mem.Allocator, input: []const u8) ![]Tuple {
    // Input is already UTF-8 in Zig, so just parse it
    return parse(allocator, input);
}

// ============================================================================
// Tests
// ============================================================================

test "form parser - simple key-value" {
    const allocator = std.testing.allocator;

    const tuples = try parse(allocator, "key=value");
    defer {
        for (tuples) |tuple| tuple.deinit(allocator);
        allocator.free(tuples);
    }

    try std.testing.expectEqual(@as(usize, 1), tuples.len);
    try std.testing.expectEqualStrings("key", tuples[0].name);
    try std.testing.expectEqualStrings("value", tuples[0].value);
}

test "form parser - multiple pairs" {
    const allocator = std.testing.allocator;

    const tuples = try parse(allocator, "a=b&c=d&e=f");
    defer {
        for (tuples) |tuple| tuple.deinit(allocator);
        allocator.free(tuples);
    }

    try std.testing.expectEqual(@as(usize, 3), tuples.len);
    try std.testing.expectEqualStrings("a", tuples[0].name);
    try std.testing.expectEqualStrings("b", tuples[0].value);
    try std.testing.expectEqualStrings("c", tuples[1].name);
    try std.testing.expectEqualStrings("d", tuples[1].value);
    try std.testing.expectEqualStrings("e", tuples[2].name);
    try std.testing.expectEqualStrings("f", tuples[2].value);
}

test "form parser - plus to space" {
    const allocator = std.testing.allocator;

    const tuples = try parse(allocator, "name=John+Doe");
    defer {
        for (tuples) |tuple| tuple.deinit(allocator);
        allocator.free(tuples);
    }

    try std.testing.expectEqual(@as(usize, 1), tuples.len);
    try std.testing.expectEqualStrings("name", tuples[0].name);
    try std.testing.expectEqualStrings("John Doe", tuples[0].value);
}

test "form parser - empty value" {
    const allocator = std.testing.allocator;

    const tuples = try parse(allocator, "key=");
    defer {
        for (tuples) |tuple| tuple.deinit(allocator);
        allocator.free(tuples);
    }

    try std.testing.expectEqual(@as(usize, 1), tuples.len);
    try std.testing.expectEqualStrings("key", tuples[0].name);
    try std.testing.expectEqualStrings("", tuples[0].value);
}

test "form parser - empty name" {
    const allocator = std.testing.allocator;

    const tuples = try parse(allocator, "=value");
    defer {
        for (tuples) |tuple| tuple.deinit(allocator);
        allocator.free(tuples);
    }

    try std.testing.expectEqual(@as(usize, 1), tuples.len);
    try std.testing.expectEqualStrings("", tuples[0].name);
    try std.testing.expectEqualStrings("value", tuples[0].value);
}

test "form parser - no equals" {
    const allocator = std.testing.allocator;

    const tuples = try parse(allocator, "key");
    defer {
        for (tuples) |tuple| tuple.deinit(allocator);
        allocator.free(tuples);
    }

    try std.testing.expectEqual(@as(usize, 1), tuples.len);
    try std.testing.expectEqualStrings("key", tuples[0].name);
    try std.testing.expectEqualStrings("", tuples[0].value);
}

test "form parser - percent encoding" {
    const allocator = std.testing.allocator;

    const tuples = try parse(allocator, "name=John%20Doe");
    defer {
        for (tuples) |tuple| tuple.deinit(allocator);
        allocator.free(tuples);
    }

    try std.testing.expectEqual(@as(usize, 1), tuples.len);
    try std.testing.expectEqualStrings("name", tuples[0].name);
    try std.testing.expectEqualStrings("John Doe", tuples[0].value);
}

test "form parser - skip empty sequences" {
    const allocator = std.testing.allocator;

    const tuples = try parse(allocator, "a=b&&c=d");
    defer {
        for (tuples) |tuple| tuple.deinit(allocator);
        allocator.free(tuples);
    }

    try std.testing.expectEqual(@as(usize, 2), tuples.len);
    try std.testing.expectEqualStrings("a", tuples[0].name);
    try std.testing.expectEqualStrings("b", tuples[0].value);
    try std.testing.expectEqualStrings("c", tuples[1].name);
    try std.testing.expectEqualStrings("d", tuples[1].value);
}

test "form parser - empty input" {
    const allocator = std.testing.allocator;

    const tuples = try parse(allocator, "");
    defer allocator.free(tuples);

    try std.testing.expectEqual(@as(usize, 0), tuples.len);
}

test "form parser - complex query" {
    const allocator = std.testing.allocator;

    const tuples = try parse(allocator, "q=search+term&page=2&sort=date");
    defer {
        for (tuples) |tuple| tuple.deinit(allocator);
        allocator.free(tuples);
    }

    try std.testing.expectEqual(@as(usize, 3), tuples.len);
    try std.testing.expectEqualStrings("q", tuples[0].name);
    try std.testing.expectEqualStrings("search term", tuples[0].value);
    try std.testing.expectEqualStrings("page", tuples[1].name);
    try std.testing.expectEqualStrings("2", tuples[1].value);
    try std.testing.expectEqualStrings("sort", tuples[2].name);
    try std.testing.expectEqualStrings("date", tuples[2].value);
}
