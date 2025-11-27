//! Header Parsing Algorithms - WHATWG Fetch Standard
//!
//! This module implements header value parsing algorithms from the Fetch spec.
//!
//! Spec: https://fetch.spec.whatwg.org/#http-headers

const std = @import("std");
const Allocator = std.mem.Allocator;
const HeaderList = @import("header_list.zig").HeaderList;

// =============================================================================
// HTTP Whitespace Helpers
// =============================================================================

/// Check if byte is HTTP tab or space (0x09 or 0x20).
pub fn isHttpTabOrSpace(byte: u8) bool {
    return byte == 0x09 or byte == 0x20;
}

/// Check if byte is HTTP whitespace (0x09 HT, 0x0A LF, 0x0D CR, 0x20 SP).
pub fn isHttpWhitespace(byte: u8) bool {
    return byte == 0x09 or byte == 0x0A or byte == 0x0D or byte == 0x20;
}

/// Trim HTTP tab/space from start and end of string.
pub fn trimHttpTabOrSpace(s: []const u8) []const u8 {
    var start: usize = 0;
    var end: usize = s.len;

    while (start < end and isHttpTabOrSpace(s[start])) {
        start += 1;
    }
    while (end > start and isHttpTabOrSpace(s[end - 1])) {
        end -= 1;
    }

    return s[start..end];
}

/// Trim HTTP whitespace from start and end of string.
pub fn trimHttpWhitespace(s: []const u8) []const u8 {
    var start: usize = 0;
    var end: usize = s.len;

    while (start < end and isHttpWhitespace(s[start])) {
        start += 1;
    }
    while (end > start and isHttpWhitespace(s[end - 1])) {
        end -= 1;
    }

    return s[start..end];
}

// =============================================================================
// Collect Sequence
// =============================================================================

/// Collect a sequence of code points matching a predicate from input starting at position.
pub fn collectSequence(input: []const u8, position: *usize, comptime predicate: fn (u8) bool) []const u8 {
    const start = position.*;
    while (position.* < input.len and predicate(input[position.*])) {
        position.* += 1;
    }
    return input[start..position.*];
}

/// Collect a sequence of code points NOT matching a predicate.
pub fn collectSequenceNot(input: []const u8, position: *usize, comptime predicate: fn (u8) bool) []const u8 {
    const start = position.*;
    while (position.* < input.len and !predicate(input[position.*])) {
        position.* += 1;
    }
    return input[start..position.*];
}

// =============================================================================
// HTTP Quoted String
// =============================================================================

/// Collect an HTTP quoted string from input starting at position.
///
/// Spec: https://fetch.spec.whatwg.org/#collect-an-http-quoted-string
///
/// @param extract_value - if true, return inner value; if false, return with quotes
pub fn collectHttpQuotedString(
    allocator: Allocator,
    input: []const u8,
    position: *usize,
    extract_value: bool,
) ![]const u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    // Step 1: Assert position is at "
    std.debug.assert(position.* < input.len and input[position.*] == '"');

    const quote_start = position.*;

    // Step 2: Advance past opening quote
    position.* += 1;

    // Step 3: While true
    while (true) {
        // Collect code points that are not " or \
        while (position.* < input.len and input[position.*] != '"' and input[position.*] != '\\') {
            try result.append(allocator, input[position.*]);
            position.* += 1;
        }

        if (position.* >= input.len) {
            break;
        }

        const quote_or_backslash = input[position.*];
        position.* += 1;

        if (quote_or_backslash == '\\') {
            if (position.* < input.len) {
                try result.append(allocator, input[position.*]);
                position.* += 1;
            } else {
                try result.append(allocator, '\\');
                break;
            }
        } else {
            // quote_or_backslash == '"'
            break;
        }
    }

    if (extract_value) {
        return try result.toOwnedSlice(allocator);
    } else {
        // Return the full quoted string including quotes
        result.deinit(allocator);
        return try allocator.dupe(u8, input[quote_start..position.*]);
    }
}

// =============================================================================
// Range Header Parsing
// =============================================================================

/// Result of parsing a range header value.
pub const RangeValue = struct {
    start: ?u64,
    end: ?u64,
};

/// Parse a single range header value.
///
/// Format: bytes=START-END or bytes=START- or bytes=-END
/// Returns null if parsing fails.
///
/// Spec: https://fetch.spec.whatwg.org/#parse-a-single-range-header-value
pub fn parseSingleRangeHeaderValue(value: []const u8, allow_whitespace: bool) ?RangeValue {
    var pos: usize = 0;

    // Step 1: If value doesn't start with "bytes", return failure
    const prefix = "bytes";
    if (value.len < prefix.len) return null;
    if (!std.ascii.eqlIgnoreCase(value[0..prefix.len], prefix)) {
        return null;
    }
    pos = prefix.len;

    // Step 2: Skip whitespace if allowed
    if (allow_whitespace) {
        while (pos < value.len and isHttpTabOrSpace(value[pos])) {
            pos += 1;
        }
    }

    // Step 3: If char != '=', return failure
    if (pos >= value.len or value[pos] != '=') {
        return null;
    }
    pos += 1;

    // Step 4: Skip whitespace if allowed
    if (allow_whitespace) {
        while (pos < value.len and isHttpTabOrSpace(value[pos])) {
            pos += 1;
        }
    }

    // Step 5: Collect digits for rangeStart
    const start_begin = pos;
    while (pos < value.len and value[pos] >= '0' and value[pos] <= '9') {
        pos += 1;
    }
    const start_str = value[start_begin..pos];
    const range_start: ?u64 = if (start_str.len > 0)
        std.fmt.parseInt(u64, start_str, 10) catch return null
    else
        null;

    // Step 6: Skip whitespace if allowed
    if (allow_whitespace) {
        while (pos < value.len and isHttpTabOrSpace(value[pos])) {
            pos += 1;
        }
    }

    // Step 7: If char != '-', return failure
    if (pos >= value.len or value[pos] != '-') {
        return null;
    }
    pos += 1;

    // Step 8: Skip whitespace if allowed
    if (allow_whitespace) {
        while (pos < value.len and isHttpTabOrSpace(value[pos])) {
            pos += 1;
        }
    }

    // Step 9: Collect digits for rangeEnd
    const end_begin = pos;
    while (pos < value.len and value[pos] >= '0' and value[pos] <= '9') {
        pos += 1;
    }
    const end_str = value[end_begin..pos];
    const range_end: ?u64 = if (end_str.len > 0)
        std.fmt.parseInt(u64, end_str, 10) catch return null
    else
        null;

    // Step 10: If not at end, return failure
    if (pos != value.len) {
        return null;
    }

    // Step 11: If both null, return failure
    if (range_start == null and range_end == null) {
        return null;
    }

    // Step 12: If both set and start > end, return failure
    if (range_start != null and range_end != null and range_start.? > range_end.?) {
        return null;
    }

    return RangeValue{ .start = range_start, .end = range_end };
}

/// Build a Content-Range header value.
///
/// Format: bytes START-END/FULL_LENGTH
pub fn buildContentRange(allocator: Allocator, start: u64, end: u64, full_length: u64) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "bytes {d}-{d}/{d}", .{ start, end, full_length });
}

/// Build a Content-Range header value for unsatisfiable range.
///
/// Format: bytes */FULL_LENGTH
pub fn buildContentRangeUnsatisfiable(allocator: Allocator, full_length: u64) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "bytes */{d}", .{full_length});
}

// =============================================================================
// Extract Header Values
// =============================================================================

/// Extract values from a header list for a given name.
///
/// Returns null if the header doesn't exist.
/// The values are parsed according to the header's ABNF.
///
/// For most headers, this returns a single-item slice with the combined value.
/// For headers that support multiple values, this splits on commas.
pub fn extractHeaderListValues(
    allocator: Allocator,
    list: *const HeaderList,
    name: []const u8,
) !?[]const []const u8 {
    // Step 1: If list doesn't contain name, return null
    if (!list.contains(name)) {
        return null;
    }

    // Step 2: Get combined value
    const value = try list.get(allocator, name) orelse return null;
    defer allocator.free(value);

    // Step 3: Parse based on header type
    // For now, return a single-item slice with the combined value
    // TODO: Add header-specific parsing for headers that need it

    var result = std.ArrayListUnmanaged([]const u8){};
    errdefer {
        for (result.items) |v| allocator.free(v);
        result.deinit(allocator);
    }

    try result.append(allocator, try allocator.dupe(u8, value));
    return try result.toOwnedSlice(allocator);
}

// =============================================================================
// MIME Type Parsing
// =============================================================================

/// A parsed MIME type.
pub const MimeType = struct {
    type_name: []const u8,
    subtype: []const u8,
    parameters: std.StringHashMapUnmanaged([]const u8),
    allocator: Allocator,

    pub fn deinit(self: *MimeType) void {
        self.allocator.free(self.type_name);
        self.allocator.free(self.subtype);
        var iter = self.parameters.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.parameters.deinit(self.allocator);
    }

    /// Get the essence (type/subtype) of the MIME type.
    pub fn essence(self: *const MimeType, allocator: Allocator) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "{s}/{s}", .{ self.type_name, self.subtype });
    }
};

/// Parse a MIME type string.
///
/// Format: type/subtype[;parameter=value]*
///
/// This is a simplified parser that handles the most common cases.
/// For full compliance, use the MIME Sniff module.
pub fn parseMimeType(allocator: Allocator, input: []const u8) !?MimeType {
    // Trim leading/trailing whitespace
    const trimmed = trimHttpWhitespace(input);
    if (trimmed.len == 0) return null;

    // Find the slash
    var slash_pos: ?usize = null;
    for (trimmed, 0..) |byte, i| {
        if (byte == '/') {
            slash_pos = i;
            break;
        }
    }

    if (slash_pos == null or slash_pos.? == 0) return null;

    // Extract type
    const type_part = trimmed[0..slash_pos.?];

    // Find the semicolon (start of parameters)
    var semicolon_pos: ?usize = null;
    for (trimmed[slash_pos.? + 1 ..], 0..) |byte, i| {
        if (byte == ';') {
            semicolon_pos = slash_pos.? + 1 + i;
            break;
        }
    }

    // Extract subtype
    const subtype_end = semicolon_pos orelse trimmed.len;
    const subtype_part = std.mem.trim(u8, trimmed[slash_pos.? + 1 .. subtype_end], " \t");

    if (subtype_part.len == 0) return null;

    var result = MimeType{
        .type_name = try std.ascii.allocLowerString(allocator, type_part),
        .subtype = try std.ascii.allocLowerString(allocator, subtype_part),
        .parameters = .{},
        .allocator = allocator,
    };
    errdefer result.deinit();

    // Parse parameters
    if (semicolon_pos != null) {
        var param_str = trimmed[semicolon_pos.? + 1 ..];
        while (param_str.len > 0) {
            // Skip whitespace
            param_str = std.mem.trimLeft(u8, param_str, " \t");
            if (param_str.len == 0) break;

            // Find the equals sign
            var eq_pos: ?usize = null;
            for (param_str, 0..) |byte, i| {
                if (byte == '=') {
                    eq_pos = i;
                    break;
                }
                if (byte == ';') break; // malformed, skip
            }

            if (eq_pos == null) break;

            const param_name = std.mem.trim(u8, param_str[0..eq_pos.?], " \t");
            param_str = param_str[eq_pos.? + 1 ..];

            // Find the value (may be quoted)
            var param_value: []const u8 = undefined;
            if (param_str.len > 0 and param_str[0] == '"') {
                // Quoted value
                var end: usize = 1;
                while (end < param_str.len) {
                    if (param_str[end] == '"') {
                        end += 1;
                        break;
                    }
                    if (param_str[end] == '\\' and end + 1 < param_str.len) {
                        end += 2;
                    } else {
                        end += 1;
                    }
                }
                param_value = param_str[1 .. end - 1]; // Remove quotes
                param_str = if (end < param_str.len) param_str[end..] else "";
            } else {
                // Unquoted value
                var end: usize = 0;
                while (end < param_str.len and param_str[end] != ';') {
                    end += 1;
                }
                param_value = std.mem.trim(u8, param_str[0..end], " \t");
                param_str = if (end < param_str.len) param_str[end + 1 ..] else "";
            }

            if (param_name.len > 0) {
                const key = try std.ascii.allocLowerString(allocator, param_name);
                errdefer allocator.free(key);
                const val = try allocator.dupe(u8, param_value);
                try result.parameters.put(allocator, key, val);
            }
        }
    }

    return result;
}

// =============================================================================
// Tests
// =============================================================================

test "isHttpTabOrSpace" {
    try std.testing.expect(isHttpTabOrSpace(0x09));
    try std.testing.expect(isHttpTabOrSpace(0x20));
    try std.testing.expect(!isHttpTabOrSpace(0x0A));
    try std.testing.expect(!isHttpTabOrSpace('a'));
}

test "isHttpWhitespace" {
    try std.testing.expect(isHttpWhitespace(0x09));
    try std.testing.expect(isHttpWhitespace(0x0A));
    try std.testing.expect(isHttpWhitespace(0x0D));
    try std.testing.expect(isHttpWhitespace(0x20));
    try std.testing.expect(!isHttpWhitespace('a'));
}

test "trimHttpTabOrSpace" {
    try std.testing.expectEqualStrings("hello", trimHttpTabOrSpace("  hello  "));
    try std.testing.expectEqualStrings("hello", trimHttpTabOrSpace("\thello\t"));
    try std.testing.expectEqualStrings("hello world", trimHttpTabOrSpace("  hello world  "));
    try std.testing.expectEqualStrings("", trimHttpTabOrSpace("   "));
}

test "trimHttpWhitespace" {
    try std.testing.expectEqualStrings("hello", trimHttpWhitespace("  hello  "));
    try std.testing.expectEqualStrings("hello", trimHttpWhitespace("\r\nhello\r\n"));
}

test "collectHttpQuotedString: simple" {
    const allocator = std.testing.allocator;
    var pos: usize = 0;
    const input = "\"hello world\" rest";

    const result = try collectHttpQuotedString(allocator, input, &pos, true);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("hello world", result);
    try std.testing.expectEqual(@as(usize, 13), pos);
}

test "collectHttpQuotedString: with escape" {
    const allocator = std.testing.allocator;
    var pos: usize = 0;
    const input = "\"hello\\\"world\"";

    const result = try collectHttpQuotedString(allocator, input, &pos, true);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("hello\"world", result);
}

test "collectHttpQuotedString: extract_value false" {
    const allocator = std.testing.allocator;
    var pos: usize = 0;
    const input = "\"hello\" rest";

    const result = try collectHttpQuotedString(allocator, input, &pos, false);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("\"hello\"", result);
}

test "parseSingleRangeHeaderValue: valid ranges" {
    // bytes=0-100
    const r1 = parseSingleRangeHeaderValue("bytes=0-100", false).?;
    try std.testing.expectEqual(@as(?u64, 0), r1.start);
    try std.testing.expectEqual(@as(?u64, 100), r1.end);

    // bytes=500-999
    const r2 = parseSingleRangeHeaderValue("bytes=500-999", false).?;
    try std.testing.expectEqual(@as(?u64, 500), r2.start);
    try std.testing.expectEqual(@as(?u64, 999), r2.end);

    // bytes=0- (open-ended)
    const r3 = parseSingleRangeHeaderValue("bytes=0-", false).?;
    try std.testing.expectEqual(@as(?u64, 0), r3.start);
    try std.testing.expect(r3.end == null);

    // bytes=-500 (suffix range)
    const r4 = parseSingleRangeHeaderValue("bytes=-500", false).?;
    try std.testing.expect(r4.start == null);
    try std.testing.expectEqual(@as(?u64, 500), r4.end);
}

test "parseSingleRangeHeaderValue: with whitespace" {
    const r = parseSingleRangeHeaderValue("bytes = 0 - 100", true).?;
    try std.testing.expectEqual(@as(?u64, 0), r.start);
    try std.testing.expectEqual(@as(?u64, 100), r.end);
}

test "parseSingleRangeHeaderValue: invalid" {
    try std.testing.expect(parseSingleRangeHeaderValue("bytes=-", false) == null); // both null
    try std.testing.expect(parseSingleRangeHeaderValue("bytes=100-50", false) == null); // start > end
    try std.testing.expect(parseSingleRangeHeaderValue("chars=0-100", false) == null); // wrong prefix
    try std.testing.expect(parseSingleRangeHeaderValue("bytes0-100", false) == null); // missing =
    try std.testing.expect(parseSingleRangeHeaderValue("bytes=0-100extra", false) == null); // extra chars
}

test "buildContentRange" {
    const allocator = std.testing.allocator;

    const range = try buildContentRange(allocator, 0, 499, 1000);
    defer allocator.free(range);
    try std.testing.expectEqualStrings("bytes 0-499/1000", range);

    const unsatisfiable = try buildContentRangeUnsatisfiable(allocator, 1000);
    defer allocator.free(unsatisfiable);
    try std.testing.expectEqualStrings("bytes */1000", unsatisfiable);
}

test "parseMimeType: simple" {
    const allocator = std.testing.allocator;

    var mime = (try parseMimeType(allocator, "text/html")).?;
    defer mime.deinit();

    try std.testing.expectEqualStrings("text", mime.type_name);
    try std.testing.expectEqualStrings("html", mime.subtype);
}

test "parseMimeType: with parameter" {
    const allocator = std.testing.allocator;

    var mime = (try parseMimeType(allocator, "text/html; charset=utf-8")).?;
    defer mime.deinit();

    try std.testing.expectEqualStrings("text", mime.type_name);
    try std.testing.expectEqualStrings("html", mime.subtype);
    try std.testing.expectEqualStrings("utf-8", mime.parameters.get("charset").?);
}

test "parseMimeType: case insensitive" {
    const allocator = std.testing.allocator;

    var mime = (try parseMimeType(allocator, "TEXT/HTML")).?;
    defer mime.deinit();

    try std.testing.expectEqualStrings("text", mime.type_name);
    try std.testing.expectEqualStrings("html", mime.subtype);
}

test "parseMimeType: invalid" {
    const allocator = std.testing.allocator;

    try std.testing.expect((try parseMimeType(allocator, "")) == null);
    try std.testing.expect((try parseMimeType(allocator, "text")) == null); // no slash
    try std.testing.expect((try parseMimeType(allocator, "/html")) == null); // empty type
    try std.testing.expect((try parseMimeType(allocator, "text/")) == null); // empty subtype
}

test "extractHeaderListValues: basic" {
    const allocator = std.testing.allocator;

    var headers = HeaderList.init(allocator);
    defer headers.deinit();

    try headers.append("Content-Type", "text/html");

    const values = try extractHeaderListValues(allocator, &headers, "Content-Type") orelse unreachable;
    defer {
        for (values) |v| allocator.free(v);
        allocator.free(values);
    }

    try std.testing.expectEqual(@as(usize, 1), values.len);
    try std.testing.expectEqualStrings("text/html", values[0]);
}

test "extractHeaderListValues: non-existent" {
    const allocator = std.testing.allocator;

    var headers = HeaderList.init(allocator);
    defer headers.deinit();

    const values = try extractHeaderListValues(allocator, &headers, "Accept");
    try std.testing.expect(values == null);
}
