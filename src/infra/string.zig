//! WHATWG Infra String Operations
//!
//! Spec: https://infra.spec.whatwg.org/#string
//!
//! A string is a sequence of 16-bit unsigned integers (code units), representing
//! UTF-16 encoded text. This matches JavaScript's internal string representation
//! and allows zero-copy interop with V8.
//!
//! # String Representation
//!
//! Infra strings use UTF-16 encoding (`[]const u16`), NOT UTF-8. This is
//! required by the WHATWG Infra specification and enables direct V8 interop.
//!
//! # Usage
//!
//! ```zig
//! const std = @import("std");
//! const string = @import("string.zig");
//!
//! const allocator = std.heap.page_allocator;
//!
//! // Convert UTF-8 (Zig default) to UTF-16 (Infra)
//! const utf8_str = "hello";
//! const infra_str = try string.utf8ToUtf16(allocator, utf8_str);
//! defer allocator.free(infra_str);
//!
//! // Convert UTF-16 (Infra) back to UTF-8 (Zig)
//! const utf8_result = try string.utf16ToUtf8(allocator, infra_str);
//! defer allocator.free(utf8_result);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const List = @import("list.zig").List;

pub const String = []const u16;

pub const InfraError = error{
    InvalidUtf8,
    InvalidUtf16,
    InvalidCodePoint,
    OutOfMemory,
};

pub fn utf8ToUtf16(allocator: Allocator, utf8: []const u8) !String {
    if (utf8.len == 0) {
        return &[_]u16{};
    }

    if (isAscii(utf8)) {
        const result = try allocator.alloc(u16, utf8.len);
        errdefer allocator.free(result);
        for (utf8, 0..) |byte, i| {
            result[i] = byte;
        }
        return result;
    }

    return utf8ToUtf16Unicode(allocator, utf8);
}

pub inline fn isAscii(bytes: []const u8) bool {
    if (bytes.len >= 16) {
        return isAsciiSimd(bytes);
    }

    for (bytes) |b| {
        if (b >= 0x80) return false;
    }
    return true;
}

fn isAsciiSimd(bytes: []const u8) bool {
    const VecSize = 16;
    const Vec = @Vector(VecSize, u8);
    const ascii_mask: Vec = @splat(0x80);

    var i: usize = 0;

    while (i + VecSize <= bytes.len) : (i += VecSize) {
        const chunk: Vec = bytes[i..][0..VecSize].*;
        const masked = chunk & ascii_mask;
        if (@reduce(.Or, masked) != 0) return false;
    }

    while (i < bytes.len) : (i += 1) {
        if (bytes[i] >= 0x80) return false;
    }

    return true;
}

fn utf8ToUtf16Unicode(allocator: Allocator, utf8: []const u8) !String {
    var result = List(u16).init(allocator);
    try result.ensureCapacity(utf8.len);
    errdefer result.deinit();

    var i: usize = 0;
    while (i < utf8.len) {
        const len = std.unicode.utf8ByteSequenceLength(utf8[i]) catch {
            return InfraError.InvalidUtf8;
        };

        if (i + len > utf8.len) {
            return InfraError.InvalidUtf8;
        }

        const codepoint = std.unicode.utf8Decode(utf8[i .. i + len]) catch {
            return InfraError.InvalidUtf8;
        };

        if (codepoint <= 0xFFFF) {
            try result.append(@intCast(codepoint));
        } else if (codepoint <= 0x10FFFF) {
            const high = @as(u16, @intCast(0xD800 + ((codepoint - 0x10000) >> 10)));
            const low = @as(u16, @intCast(0xDC00 + ((codepoint - 0x10000) & 0x3FF)));
            try result.append(high);
            try result.append(low);
        } else {
            return InfraError.InvalidUtf8;
        }

        i += len;
    }

    return result.toOwnedSlice();
}

pub fn utf16ToUtf8(allocator: Allocator, utf16: String) ![]const u8 {
    if (utf16.len == 0) {
        return &[_]u8{};
    }

    var result = List(u8).init(allocator);
    try result.ensureCapacity(utf16.len);
    errdefer result.deinit();

    var i: usize = 0;
    while (i < utf16.len) {
        const unit = utf16[i];

        const codepoint: u21 = blk: {
            if (unit >= 0xD800 and unit <= 0xDBFF) {
                if (i + 1 >= utf16.len) {
                    return InfraError.InvalidUtf16;
                }
                const low = utf16[i + 1];
                if (low < 0xDC00 or low > 0xDFFF) {
                    return InfraError.InvalidUtf16;
                }
                i += 1;
                const high_bits = @as(u21, unit - 0xD800);
                const low_bits = @as(u21, low - 0xDC00);
                break :blk 0x10000 + (high_bits << 10) + low_bits;
            } else if (unit >= 0xDC00 and unit <= 0xDFFF) {
                return InfraError.InvalidUtf16;
            } else {
                break :blk @as(u21, unit);
            }
        };

        var buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(codepoint, &buf) catch {
            return InfraError.InvalidCodePoint;
        };
        try result.appendSlice(buf[0..len]);

        i += 1;
    }

    return result.toOwnedSlice();
}

/// ASCII lowercase a string.
/// WHATWG Infra Standard §4.6 line 697
pub fn asciiLowercase(allocator: Allocator, string: String) !String {
    if (string.len == 0) {
        return &[_]u16{};
    }

    const result = try allocator.alloc(u16, string.len);
    errdefer allocator.free(result);

    for (string, 0..) |c, i| {
        result[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }

    return result;
}

/// ASCII uppercase a string.
/// WHATWG Infra Standard §4.6 line 699
pub fn asciiUppercase(allocator: Allocator, string: String) !String {
    if (string.len == 0) {
        return &[_]u16{};
    }

    const result = try allocator.alloc(u16, string.len);
    errdefer allocator.free(result);

    for (string, 0..) |c, i| {
        result[i] = if (c >= 'a' and c <= 'z') c - 32 else c;
    }

    return result;
}

pub inline fn isAsciiString(string: String) bool {
    for (string) |c| {
        if (c > 0x7F) return false;
    }
    return true;
}

/// An isomorphic string is a string whose code points are all in the range
/// U+0000 NULL to U+00FF (ÿ), inclusive.
/// WHATWG Infra Standard §4.6 line 571
pub inline fn isIsomorphicString(string: String) bool {
    for (string) |c| {
        if (c > 0xFF) return false;
    }
    return true;
}

/// A scalar value string is a string whose code points are all scalar values
/// (no surrogates).
/// WHATWG Infra Standard §4.6 line 573
pub inline fn isScalarValueString(string: String) bool {
    const code_point = @import("code_point.zig");
    for (string) |c| {
        if (code_point.isSurrogate(c)) return false;
    }
    return true;
}

/// Check if two strings are identical (code unit sequence comparison).
/// WHATWG Infra Standard §4.6 lines 585-587
///
/// A string a **is** or is **identical to** a string b if it consists of
/// the same sequence of code units.
///
/// Note: Except where otherwise stated, all string comparisons use is.
/// This type of comparison is case-sensitive, normalization-sensitive,
/// and order-sensitive for combining marks.
pub fn is(a: String, b: String) bool {
    if (a.len != b.len) return false;

    // Use SIMD for long strings (>=16 code units)
    if (a.len >= 16) {
        return isSimd(a, b);
    }

    // Scalar path for short strings
    for (a, b) |code_unit_a, code_unit_b| {
        if (code_unit_a != code_unit_b) return false;
    }

    return true;
}

fn isSimd(a: String, b: String) bool {
    const VecSize = 8; // Process 8 u16 values at a time (16 bytes)
    const Vec = @Vector(VecSize, u16);

    var i: usize = 0;

    // SIMD loop - process 8 u16 at a time
    while (i + VecSize <= a.len) : (i += VecSize) {
        const chunk_a: Vec = a[i..][0..VecSize].*;
        const chunk_b: Vec = b[i..][0..VecSize].*;

        // Check if all elements are equal
        const matches = chunk_a == chunk_b;
        if (!@reduce(.And, matches)) return false;
    }

    // Scalar tail for remaining elements
    while (i < a.len) : (i += 1) {
        if (a[i] != b[i]) return false;
    }

    return true;
}

/// Alias for is() - check if two strings are identical.
/// WHATWG Infra Standard §4.6 lines 585-587
pub const isIdenticalTo = is;

/// Alias for is() - common name for string equality
pub const eql = is;

/// Check if a haystack contains a needle substring.
/// Returns true if needle is found in haystack, false otherwise.
pub fn contains(haystack: String, needle: String) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;

    // Single character optimization
    if (needle.len == 1) {
        return indexOf(haystack, needle[0]) != null;
    }

    // For substring search, use a simple but efficient algorithm
    const max_start = haystack.len - needle.len;
    var start: usize = 0;

    while (start <= max_start) : (start += 1) {
        // Check first character quickly
        if (haystack[start] != needle[0]) continue;

        // Check rest of substring
        var matches = true;
        var j: usize = 1;
        while (j < needle.len) : (j += 1) {
            if (haystack[start + j] != needle[j]) {
                matches = false;
                break;
            }
        }
        if (matches) return true;
    }

    return false;
}

/// Find the first occurrence of a code unit in a string.
/// Returns the index if found, null otherwise.
pub fn indexOf(haystack: String, needle: u16) ?usize {
    // Use SIMD for long strings (>=16 code units)
    if (haystack.len >= 16) {
        return indexOfSimd(haystack, needle);
    }

    // Scalar path for short strings
    for (haystack, 0..) |code_unit, i| {
        if (code_unit == needle) return i;
    }
    return null;
}

fn indexOfSimd(haystack: String, needle: u16) ?usize {
    const VecSize = 8; // Process 8 u16 values at a time (16 bytes)
    const Vec = @Vector(VecSize, u16);
    const needle_vec: Vec = @splat(needle);

    var i: usize = 0;

    // SIMD loop - process 8 u16 at a time
    while (i + VecSize <= haystack.len) : (i += VecSize) {
        const chunk: Vec = haystack[i..][0..VecSize].*;
        const matches = chunk == needle_vec;

        // Check if any element matched
        if (@reduce(.Or, matches)) {
            // Find which element matched
            var j: usize = 0;
            while (j < VecSize) : (j += 1) {
                if (matches[j]) return i + j;
            }
        }
    }

    // Scalar tail for remaining elements
    while (i < haystack.len) : (i += 1) {
        if (haystack[i] == needle) return i;
    }

    return null;
}

/// Check if two strings are an ASCII case-insensitive match.
/// WHATWG Infra Standard §4.6 line 701
pub fn isAsciiCaseInsensitiveMatch(a: String, b: String) bool {
    if (a.len != b.len) return false;

    for (a, b) |ca, cb| {
        const lower_a = if (ca >= 'A' and ca <= 'Z') ca + 32 else ca;
        const lower_b = if (cb >= 'A' and cb <= 'Z') cb + 32 else cb;
        if (lower_a != lower_b) return false;
    }

    return true;
}

pub fn asciiByteLength(string: String) InfraError!usize {
    for (string) |c| {
        if (c > 0x7F) return InfraError.InvalidCodePoint;
    }
    return string.len;
}

pub inline fn isAsciiWhitespace(c: u16) bool {
    return c == 0x0009 or c == 0x000A or c == 0x000C or c == 0x000D or c == 0x0020;
}

/// Strip leading and trailing ASCII whitespace from a string.
/// WHATWG Infra Standard §4.6 line 719
pub fn stripLeadingAndTrailingAsciiWhitespace(allocator: Allocator, string: String) !String {
    if (string.len == 0) {
        return &[_]u16{};
    }

    var start: usize = 0;
    while (start < string.len and isAsciiWhitespace(string[start])) {
        start += 1;
    }

    if (start == string.len) {
        return &[_]u16{};
    }

    var end: usize = string.len;
    while (end > start and isAsciiWhitespace(string[end - 1])) {
        end -= 1;
    }

    const result = try allocator.alloc(u16, end - start);
    @memcpy(result, string[start..end]);
    return result;
}

pub fn stripNewlines(allocator: Allocator, string: String) !String {
    if (string.len == 0) {
        return &[_]u16{};
    }

    var result = List(u16).init(allocator);
    try result.ensureCapacity(string.len);
    errdefer result.deinit();

    for (string) |c| {
        if (c != 0x000A and c != 0x000D) {
            try result.append(c);
        }
    }

    return result.toOwnedSlice();
}

pub fn normalizeNewlines(allocator: Allocator, string: String) !String {
    if (string.len == 0) {
        return &[_]u16{};
    }

    var result = List(u16).init(allocator);
    try result.ensureCapacity(string.len);
    errdefer result.deinit();

    var i: usize = 0;
    while (i < string.len) {
        const c = string[i];
        if (c == 0x000D) {
            if (i + 1 < string.len and string[i + 1] == 0x000A) {
                i += 1;
            }
            try result.append(0x000A);
        } else {
            try result.append(c);
        }
        i += 1;
    }

    return result.toOwnedSlice();
}

/// Split a string on ASCII whitespace.
/// WHATWG Infra Standard §4.6 line 763-779
pub fn splitOnAsciiWhitespace(allocator: Allocator, input: String) ![]String {
    if (input.len == 0) {
        return &[_]String{};
    }

    var position: usize = 0;
    var tokens = List(String).init(allocator);
    errdefer {
        for (tokens.items()) |token| {
            allocator.free(token);
        }
        tokens.deinit();
    }

    skipAsciiWhitespace(input, &position);

    while (position < input.len) {
        const token = try collectSequence(allocator, input, &position, struct {
            fn notWhitespace(c: u16) bool {
                return !isAsciiWhitespace(c);
            }
        }.notWhitespace);
        try tokens.append(token);
        skipAsciiWhitespace(input, &position);
    }

    return tokens.toOwnedSlice();
}

/// Split a string on commas.
/// WHATWG Infra Standard §4.6 line 781-803
pub fn splitOnCommas(allocator: Allocator, input: String) ![]String {
    if (input.len == 0) {
        return &[_]String{};
    }

    var position: usize = 0;
    var tokens = List(String).init(allocator);
    errdefer {
        for (tokens.items()) |token| {
            allocator.free(token);
        }
        tokens.deinit();
    }

    while (position < input.len) {
        const token = try collectSequence(allocator, input, &position, struct {
            fn notComma(c: u16) bool {
                return c != ',';
            }
        }.notComma);
        const stripped = try stripLeadingAndTrailingAsciiWhitespace(allocator, token);
        allocator.free(token);
        try tokens.append(stripped);

        if (position < input.len) {
            position += 1;
        }
    }

    return tokens.toOwnedSlice();
}

/// Collect a sequence of code points meeting a condition.
/// WHATWG Infra Standard §4.6 line 723-737
pub fn collectSequence(allocator: Allocator, input: String, position: *usize, condition: fn (u16) bool) !String {
    var result = List(u16).init(allocator);
    errdefer result.deinit();

    while (position.* < input.len and condition(input[position.*])) {
        try result.append(input[position.*]);
        position.* += 1;
    }

    return result.toOwnedSlice();
}

pub fn skipAsciiWhitespace(input: String, position: *usize) void {
    while (position.* < input.len and isAsciiWhitespace(input[position.*])) {
        position.* += 1;
    }
}

/// Strictly split a string on a delimiter code point.
/// WHATWG Infra Standard §4.6 line 739-759
pub fn strictlySplit(allocator: Allocator, input: String, delimiter: u16) ![]String {
    const NotDelimiter = struct {
        delim: u16,
        fn check(self: @This(), c: u16) bool {
            return c != self.delim;
        }
    };

    var position: usize = 0;
    var tokens = List(String).init(allocator);
    errdefer {
        for (tokens.items()) |token| {
            allocator.free(token);
        }
        tokens.deinit();
    }

    const checker = NotDelimiter{ .delim = delimiter };
    var result = List(u16).init(allocator);
    errdefer result.deinit();

    while (position < input.len and checker.check(input[position])) {
        try result.append(input[position]);
        position += 1;
    }
    try tokens.append(try result.toOwnedSlice());

    while (position < input.len) {
        position += 1;
        var token_result = List(u16).init(allocator);
        errdefer token_result.deinit();

        while (position < input.len and checker.check(input[position])) {
            try token_result.append(input[position]);
            position += 1;
        }
        try tokens.append(try token_result.toOwnedSlice());
    }

    return tokens.toOwnedSlice();
}

pub fn codePointSubstring(allocator: Allocator, string: String, start: usize, length: usize) !String {
    // Bounds validation assertions
    std.debug.assert(start <= std.math.maxInt(usize) - length); // Prevent overflow in start + length

    var result = List(u16).init(allocator);
    try result.ensureCapacity(length * 2);
    errdefer result.deinit();

    var code_point_index: usize = 0;
    var i: usize = 0;

    while (i < string.len and code_point_index < start) {
        const c = string[i];
        if (c >= 0xD800 and c <= 0xDBFF and i + 1 < string.len) {
            const low = string[i + 1];
            if (low >= 0xDC00 and low <= 0xDFFF) {
                i += 2;
                code_point_index += 1;
                continue;
            }
        }
        i += 1;
        code_point_index += 1;
    }

    var collected: usize = 0;
    while (i < string.len and collected < length) {
        const c = string[i];
        if (c >= 0xD800 and c <= 0xDBFF and i + 1 < string.len) {
            const low = string[i + 1];
            if (low >= 0xDC00 and low <= 0xDFFF) {
                try result.append(c);
                try result.append(low);
                i += 2;
                collected += 1;
                continue;
            }
        }
        try result.append(c);
        i += 1;
        collected += 1;
    }

    return result.toOwnedSlice();
}

pub fn codePointSubstringByPositions(allocator: Allocator, string: String, start: usize, end: usize) !String {
    // Bounds validation: end must be >= start
    std.debug.assert(end >= start);
    return codePointSubstring(allocator, string, start, end - start);
}

pub fn codePointSubstringToEnd(allocator: Allocator, string: String, start: usize) !String {
    var code_point_length: usize = 0;
    var i: usize = 0;
    while (i < string.len) {
        const c = string[i];
        if (c >= 0xD800 and c <= 0xDBFF and i + 1 < string.len) {
            const low = string[i + 1];
            if (low >= 0xDC00 and low <= 0xDFFF) {
                i += 2;
                code_point_length += 1;
                continue;
            }
        }
        i += 1;
        code_point_length += 1;
    }

    // Fix underflow: if start is beyond the end, return empty string
    if (start >= code_point_length) {
        return try allocator.dupe(u16, &[_]u16{});
    }

    return codePointSubstring(allocator, string, start, code_point_length - start);
}

/// Check if a string is a code unit prefix of another string.
/// WHATWG Infra Standard §4.6 line 591-608
pub fn isCodeUnitPrefix(potentialPrefix: String, input: String) bool {
    if (potentialPrefix.len > input.len) return false;

    var i: usize = 0;
    while (i < potentialPrefix.len) {
        if (potentialPrefix[i] != input[i]) return false;
        i += 1;
    }

    return true;
}

/// Check if a string is a code unit suffix of another string.
/// WHATWG Infra Standard §4.6 line 613-633
pub fn isCodeUnitSuffix(potentialSuffix: String, input: String) bool {
    if (potentialSuffix.len > input.len) return false;

    var i: usize = 1;
    while (i <= potentialSuffix.len) : (i += 1) {
        const suffix_idx = potentialSuffix.len - i;
        const input_idx = input.len - i;
        if (potentialSuffix[suffix_idx] != input[input_idx]) return false;
    }

    return true;
}

/// Check if one string is code unit less than another.
/// WHATWG Infra Standard §4.6 line 639-649
pub fn codeUnitLessThan(a: String, b: String) bool {
    if (isCodeUnitPrefix(b, a)) return false;
    if (isCodeUnitPrefix(a, b)) return true;

    const min_len = @min(a.len, b.len);
    for (0..min_len) |i| {
        if (a[i] < b[i]) return true;
        if (a[i] > b[i]) return false;
    }

    return a.len < b.len;
}

pub fn codeUnitSubstring(string: String, start: usize, length: usize) String {
    const end = @min(start + length, string.len);
    return string[start..end];
}

pub fn codeUnitSubstringByPositions(string: String, start: usize, end: usize) String {
    return string[start..@min(end, string.len)];
}

pub fn codeUnitSubstringToEnd(string: String, start: usize) String {
    return string[start..];
}

/// Convert a string into a scalar value string.
/// WHATWG Infra Standard §4.6 line 577-581
pub fn convertToScalarValueString(allocator: Allocator, string: String) !String {
    if (string.len == 0) {
        return &[_]u16{};
    }

    var result = List(u16).init(allocator);
    try result.ensureCapacity(string.len);
    errdefer result.deinit();

    var i: usize = 0;
    while (i < string.len) {
        const c = string[i];

        if (c >= 0xD800 and c <= 0xDBFF and i + 1 < string.len) {
            const low = string[i + 1];
            if (low >= 0xDC00 and low <= 0xDFFF) {
                try result.append(c);
                try result.append(low);
                i += 2;
                continue;
            }
        }

        if (c >= 0xD800 and c <= 0xDFFF) {
            try result.append(0xFFFD);
        } else {
            try result.append(c);
        }

        i += 1;
    }

    return result.toOwnedSlice();
}

/// Strip and collapse ASCII whitespace in a string.
/// WHATWG Infra Standard §4.6 line 721
pub fn stripAndCollapseAsciiWhitespace(allocator: Allocator, string: String) !String {
    if (string.len == 0) {
        return &[_]u16{};
    }

    var result = List(u16).init(allocator);
    try result.ensureCapacity(string.len);
    errdefer result.deinit();

    var in_whitespace = false;
    for (string) |c| {
        if (isAsciiWhitespace(c)) {
            in_whitespace = true;
        } else {
            if (in_whitespace and result.len > 0) {
                try result.append(0x0020);
            }
            try result.append(c);
            in_whitespace = false;
        }
    }

    return result.toOwnedSlice();
}

pub fn asciiEncode(allocator: Allocator, string: String) ![]const u8 {
    const bytes_module = @import("bytes.zig");
    return bytes_module.isomorphicEncode(allocator, string);
}

pub fn asciiDecode(allocator: Allocator, bytes: []const u8) !String {
    const bytes_module = @import("bytes.zig");
    return bytes_module.isomorphicDecode(allocator, bytes);
}

/// Concatenate a list of strings with an optional separator.
/// WHATWG Infra Standard §4.6 line 805-812
pub fn concatenate(allocator: Allocator, strings: []const String, separator: ?String) !String {
    if (strings.len == 0) {
        return &[_]u16{};
    }

    const sep = separator orelse &[_]u16{};

    var total_len: usize = 0;
    for (strings) |s| {
        total_len += s.len;
    }
    if (strings.len > 1) {
        total_len += sep.len * (strings.len - 1);
    }

    if (total_len == 0) {
        return &[_]u16{};
    }

    const result = try allocator.alloc(u16, total_len);
    var pos: usize = 0;
    for (strings, 0..) |s, idx| {
        if (idx > 0 and sep.len > 0) {
            @memcpy(result[pos .. pos + sep.len], sep);
            pos += sep.len;
        }
        @memcpy(result[pos .. pos + s.len], s);
        pos += s.len;
    }

    return result;
}

test "utf8ToUtf16 - empty string" {
    const allocator = std.testing.allocator;
    const result = try utf8ToUtf16(allocator, "");
    defer allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "utf8ToUtf16 - ASCII string" {
    const allocator = std.testing.allocator;
    const result = try utf8ToUtf16(allocator, "hello");
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "utf8ToUtf16 - Unicode BMP" {
    const allocator = std.testing.allocator;
    const result = try utf8ToUtf16(allocator, "héllo");
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 0x00E9, 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "utf8ToUtf16 - Unicode with surrogate pairs" {
    const allocator = std.testing.allocator;
    const result = try utf8ToUtf16(allocator, "💩");
    defer allocator.free(result);

    const expected = [_]u16{ 0xD83D, 0xDCA9 };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "utf8ToUtf16 - invalid UTF-8" {
    const allocator = std.testing.allocator;
    const invalid = [_]u8{ 0xFF, 0xFE };
    const result = utf8ToUtf16(allocator, &invalid);
    try std.testing.expectError(InfraError.InvalidUtf8, result);
}

test "utf16ToUtf8 - empty string" {
    const allocator = std.testing.allocator;
    const input = [_]u16{};
    const result = try utf16ToUtf8(allocator, &input);
    defer allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "utf16ToUtf8 - ASCII string" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try utf16ToUtf8(allocator, &input);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "utf16ToUtf8 - Unicode BMP" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 0x00E9, 'l', 'l', 'o' };
    const result = try utf16ToUtf8(allocator, &input);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("héllo", result);
}

test "utf16ToUtf8 - surrogate pairs" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 0xD83D, 0xDCA9 };
    const result = try utf16ToUtf8(allocator, &input);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("💩", result);
}

test "utf16ToUtf8 - unpaired high surrogate" {
    const allocator = std.testing.allocator;
    const input = [_]u16{0xD83D};
    const result = utf16ToUtf8(allocator, &input);
    try std.testing.expectError(InfraError.InvalidUtf16, result);
}

test "utf16ToUtf8 - unpaired low surrogate" {
    const allocator = std.testing.allocator;
    const input = [_]u16{0xDCA9};
    const result = utf16ToUtf8(allocator, &input);
    try std.testing.expectError(InfraError.InvalidUtf16, result);
}

test "conversion roundtrip - ASCII" {
    const allocator = std.testing.allocator;
    const original = "hello world";

    const utf16 = try utf8ToUtf16(allocator, original);
    defer allocator.free(utf16);

    const utf8 = try utf16ToUtf8(allocator, utf16);
    defer allocator.free(utf8);

    try std.testing.expectEqualStrings(original, utf8);
}

test "conversion roundtrip - Unicode" {
    const allocator = std.testing.allocator;
    const original = "hello 世界 💩";

    const utf16 = try utf8ToUtf16(allocator, original);
    defer allocator.free(utf16);

    const utf8 = try utf16ToUtf8(allocator, utf16);
    defer allocator.free(utf8);

    try std.testing.expectEqualStrings(original, utf8);
}

test "asciiLowercase - empty string" {
    const allocator = std.testing.allocator;
    const input = [_]u16{};
    const result = try asciiLowercase(allocator, &input);
    defer allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "asciiLowercase - ASCII uppercase" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'H', 'E', 'L', 'L', 'O' };
    const result = try asciiLowercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "asciiLowercase - mixed case" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'H', 'e', 'L', 'l', 'O' };
    const result = try asciiLowercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "asciiLowercase - already lowercase" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try asciiLowercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "asciiLowercase - non-ASCII unchanged" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'H', 0x00E9, 'L', 'L', 'O' };
    const result = try asciiLowercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 0x00E9, 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "asciiUppercase - empty string" {
    const allocator = std.testing.allocator;
    const input = [_]u16{};
    const result = try asciiUppercase(allocator, &input);
    defer allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "asciiUppercase - ASCII lowercase" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try asciiUppercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'H', 'E', 'L', 'L', 'O' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "asciiUppercase - mixed case" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'H', 'e', 'L', 'l', 'O' };
    const result = try asciiUppercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'H', 'E', 'L', 'L', 'O' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "isAsciiString - pure ASCII" {
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(isAsciiString(&input));
}

test "isAsciiString - contains Unicode" {
    const input = [_]u16{ 'h', 0x00E9, 'l', 'l', 'o' };
    try std.testing.expect(!isAsciiString(&input));
}

test "isAsciiString - empty string" {
    const input = [_]u16{};
    try std.testing.expect(isAsciiString(&input));
}

test "isIsomorphicString - pure ASCII" {
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(isIsomorphicString(&input));
}

test "isIsomorphicString - Latin-1 range" {
    const input = [_]u16{ 'h', 0x00E9, 0x00FF, 'o' };
    try std.testing.expect(isIsomorphicString(&input));
}

test "isIsomorphicString - exceeds Latin-1" {
    const input = [_]u16{ 'h', 0x0100, 'o' };
    try std.testing.expect(!isIsomorphicString(&input));
}

test "isIsomorphicString - empty string" {
    const input = [_]u16{};
    try std.testing.expect(isIsomorphicString(&input));
}

test "isScalarValueString - no surrogates" {
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(isScalarValueString(&input));
}

test "isScalarValueString - contains lead surrogate" {
    const input = [_]u16{ 'h', 0xD800, 'o' };
    try std.testing.expect(!isScalarValueString(&input));
}

test "isScalarValueString - contains trail surrogate" {
    const input = [_]u16{ 'h', 0xDC00, 'o' };
    try std.testing.expect(!isScalarValueString(&input));
}

test "isScalarValueString - empty string" {
    const input = [_]u16{};
    try std.testing.expect(isScalarValueString(&input));
}

test "is - identical strings" {
    const a = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const b = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(is(&a, &b));
}

test "is - different strings" {
    const a = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const b = [_]u16{ 'w', 'o', 'r', 'l', 'd' };
    try std.testing.expect(!is(&a, &b));
}

test "is - case sensitive" {
    const a = [_]u16{ 'H', 'E', 'L', 'L', 'O' };
    const b = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(!is(&a, &b));
}

test "is - different lengths" {
    const a = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const b = [_]u16{ 'h', 'e', 'l', 'l' };
    try std.testing.expect(!is(&a, &b));
}

test "is - empty strings" {
    const a = [_]u16{};
    const b = [_]u16{};
    try std.testing.expect(is(&a, &b));
}

test "is - Unicode strings" {
    const a = [_]u16{ 0xD83D, 0xDCA9, 'a' };
    const b = [_]u16{ 0xD83D, 0xDCA9, 'a' };
    try std.testing.expect(is(&a, &b));
}

test "is - normalization sensitive" {
    const a = [_]u16{0x00E9};
    const b = [_]u16{ 'e', 0x0301 };
    try std.testing.expect(!is(&a, &b));
}

test "isIdenticalTo - alias works" {
    const a = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const b = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(isIdenticalTo(&a, &b));
}

test "isAsciiCaseInsensitiveMatch - match same case" {
    const a = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const b = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(isAsciiCaseInsensitiveMatch(&a, &b));
}

test "isAsciiCaseInsensitiveMatch - match different case" {
    const a = [_]u16{ 'H', 'E', 'L', 'L', 'O' };
    const b = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(isAsciiCaseInsensitiveMatch(&a, &b));
}

test "isAsciiCaseInsensitiveMatch - no match" {
    const a = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const b = [_]u16{ 'w', 'o', 'r', 'l', 'd' };
    try std.testing.expect(!isAsciiCaseInsensitiveMatch(&a, &b));
}

test "isAsciiCaseInsensitiveMatch - different lengths" {
    const a = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const b = [_]u16{ 'h', 'e', 'l', 'l' };
    try std.testing.expect(!isAsciiCaseInsensitiveMatch(&a, &b));
}

test "asciiByteLength - ASCII string" {
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try asciiByteLength(&input);
    try std.testing.expectEqual(@as(usize, 5), result);
}

test "asciiByteLength - non-ASCII error" {
    const input = [_]u16{ 'h', 0x00E9, 'l', 'l', 'o' };
    const result = asciiByteLength(&input);
    try std.testing.expectError(InfraError.InvalidCodePoint, result);
}

test "asciiByteLength - beyond byte range" {
    const input = [_]u16{ 'h', 0x0100, 'l', 'l', 'o' };
    const result = asciiByteLength(&input);
    try std.testing.expectError(InfraError.InvalidCodePoint, result);
}

test "isAsciiWhitespace - tab" {
    try std.testing.expect(isAsciiWhitespace(0x0009));
}

test "isAsciiWhitespace - newline" {
    try std.testing.expect(isAsciiWhitespace(0x000A));
}

test "isAsciiWhitespace - form feed" {
    try std.testing.expect(isAsciiWhitespace(0x000C));
}

test "isAsciiWhitespace - carriage return" {
    try std.testing.expect(isAsciiWhitespace(0x000D));
}

test "isAsciiWhitespace - space" {
    try std.testing.expect(isAsciiWhitespace(0x0020));
}

test "isAsciiWhitespace - non-whitespace" {
    try std.testing.expect(!isAsciiWhitespace('a'));
    try std.testing.expect(!isAsciiWhitespace('Z'));
    try std.testing.expect(!isAsciiWhitespace('0'));
}

test "stripLeadingAndTrailingAsciiWhitespace - both ends" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ ' ', '\t', 'h', 'e', 'l', 'l', 'o', ' ', '\n' };
    const result = try stripLeadingAndTrailingAsciiWhitespace(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "stripLeadingAndTrailingAsciiWhitespace - leading only" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ ' ', '\t', 'h', 'e', 'l', 'l', 'o' };
    const result = try stripLeadingAndTrailingAsciiWhitespace(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "stripLeadingAndTrailingAsciiWhitespace - trailing only" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o', ' ', '\n' };
    const result = try stripLeadingAndTrailingAsciiWhitespace(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "stripLeadingAndTrailingAsciiWhitespace - none" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try stripLeadingAndTrailingAsciiWhitespace(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "stripLeadingAndTrailingAsciiWhitespace - all whitespace" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ ' ', '\t', '\n' };
    const result = try stripLeadingAndTrailingAsciiWhitespace(allocator, &input);
    defer allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "stripNewlines - LF and CR" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', '\n', 'l', 'l', '\r', 'o' };
    const result = try stripNewlines(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "stripNewlines - no newlines" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try stripNewlines(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "normalizeNewlines - CRLF to LF" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'i', '\r', '\n', 't', 'h', 'e', 'r', 'e' };
    const result = try normalizeNewlines(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'i', '\n', 't', 'h', 'e', 'r', 'e' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "normalizeNewlines - CR to LF" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'i', '\r', 't', 'h', 'e', 'r', 'e' };
    const result = try normalizeNewlines(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'i', '\n', 't', 'h', 'e', 'r', 'e' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "normalizeNewlines - LF unchanged" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'i', '\n', 't', 'h', 'e', 'r', 'e' };
    const result = try normalizeNewlines(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'i', '\n', 't', 'h', 'e', 'r', 'e' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "splitOnAsciiWhitespace - single space" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd' };
    const result = try splitOnAsciiWhitespace(allocator, &input);
    defer {
        for (result) |token| {
            allocator.free(token);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 2), result.len);

    const expected1 = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected1, result[0]);

    const expected2 = [_]u16{ 'w', 'o', 'r', 'l', 'd' };
    try std.testing.expectEqualSlices(u16, &expected2, result[1]);
}

test "splitOnAsciiWhitespace - multiple spaces" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'a', ' ', ' ', 'b', ' ', 'c' };
    const result = try splitOnAsciiWhitespace(allocator, &input);
    defer {
        for (result) |token| {
            allocator.free(token);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 3), result.len);

    const expected1 = [_]u16{'a'};
    try std.testing.expectEqualSlices(u16, &expected1, result[0]);

    const expected2 = [_]u16{'b'};
    try std.testing.expectEqualSlices(u16, &expected2, result[1]);

    const expected3 = [_]u16{'c'};
    try std.testing.expectEqualSlices(u16, &expected3, result[2]);
}

test "splitOnAsciiWhitespace - mixed whitespace" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'a', '\t', 'b', '\n', 'c' };
    const result = try splitOnAsciiWhitespace(allocator, &input);
    defer {
        for (result) |token| {
            allocator.free(token);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 3), result.len);
}

test "splitOnAsciiWhitespace - empty string" {
    const allocator = std.testing.allocator;
    const input = [_]u16{};
    const result = try splitOnAsciiWhitespace(allocator, &input);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "splitOnCommas - basic" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'a', ',', 'b', ',', 'c' };
    const result = try splitOnCommas(allocator, &input);
    defer {
        for (result) |token| {
            allocator.free(token);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 3), result.len);

    const expected1 = [_]u16{'a'};
    try std.testing.expectEqualSlices(u16, &expected1, result[0]);

    const expected2 = [_]u16{'b'};
    try std.testing.expectEqualSlices(u16, &expected2, result[1]);

    const expected3 = [_]u16{'c'};
    try std.testing.expectEqualSlices(u16, &expected3, result[2]);
}

test "splitOnCommas - with whitespace" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'a', ' ', ',', ' ', 'b', ' ', ',', ' ', 'c' };
    const result = try splitOnCommas(allocator, &input);
    defer {
        for (result) |token| {
            allocator.free(token);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 3), result.len);

    const expected1 = [_]u16{'a'};
    try std.testing.expectEqualSlices(u16, &expected1, result[0]);

    const expected2 = [_]u16{'b'};
    try std.testing.expectEqualSlices(u16, &expected2, result[1]);

    const expected3 = [_]u16{'c'};
    try std.testing.expectEqualSlices(u16, &expected3, result[2]);
}

test "splitOnCommas - empty string" {
    const allocator = std.testing.allocator;
    const input = [_]u16{};
    const result = try splitOnCommas(allocator, &input);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "concatenate - multiple strings" {
    const allocator = std.testing.allocator;

    const str1 = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const str2 = [_]u16{' '};
    const str3 = [_]u16{ 'w', 'o', 'r', 'l', 'd' };

    const strings = [_]String{ &str1, &str2, &str3 };
    const result = try concatenate(allocator, &strings, null);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "concatenate - empty list" {
    const allocator = std.testing.allocator;
    const strings = [_]String{};
    const result = try concatenate(allocator, &strings, null);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "concatenate - with separator" {
    const allocator = std.testing.allocator;

    const str1 = [_]u16{ 'a', 'b' };
    const str2 = [_]u16{ 'c', 'd' };
    const sep = [_]u16{'-'};

    const strings = [_]String{ &str1, &str2 };
    const result = try concatenate(allocator, &strings, &sep);
    defer allocator.free(result);

    const expected = [_]u16{ 'a', 'b', '-', 'c', 'd' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "collectSequence - basic" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'a', 'b', 'c', ' ', 'd', 'e' };
    var position: usize = 0;

    const result = try collectSequence(allocator, &input, &position, struct {
        fn notSpace(c: u16) bool {
            return c != ' ';
        }
    }.notSpace);
    defer allocator.free(result);

    const expected = [_]u16{ 'a', 'b', 'c' };
    try std.testing.expectEqualSlices(u16, &expected, result);
    try std.testing.expectEqual(@as(usize, 3), position);
}

test "skipAsciiWhitespace - basic" {
    const input = [_]u16{ ' ', '\t', '\n', 'a', 'b' };
    var position: usize = 0;

    skipAsciiWhitespace(&input, &position);

    try std.testing.expectEqual(@as(usize, 3), position);
}

test "strictlySplit - basic" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'a', ',', 'b', ',', 'c' };
    const result = try strictlySplit(allocator, &input, ',');
    defer {
        for (result) |token| {
            allocator.free(token);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 3), result.len);

    const expected1 = [_]u16{'a'};
    try std.testing.expectEqualSlices(u16, &expected1, result[0]);

    const expected2 = [_]u16{'b'};
    try std.testing.expectEqualSlices(u16, &expected2, result[1]);

    const expected3 = [_]u16{'c'};
    try std.testing.expectEqualSlices(u16, &expected3, result[2]);
}

test "strictlySplit - empty tokens" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'a', ',', ',', 'b' };
    const result = try strictlySplit(allocator, &input, ',');
    defer {
        for (result) |token| {
            allocator.free(token);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(@as(usize, 1), result[0].len);
    try std.testing.expectEqual(@as(usize, 0), result[1].len);
    try std.testing.expectEqual(@as(usize, 1), result[2].len);
}

test "codePointSubstring - ASCII only" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try codePointSubstring(allocator, &input, 1, 3);
    defer allocator.free(result);

    const expected = [_]u16{ 'e', 'l', 'l' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "codePointSubstring - with surrogate pairs" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 0xD83D, 0xDCA9, 'a', 0xD83D, 0xDE00 };
    const result = try codePointSubstring(allocator, &input, 0, 2);
    defer allocator.free(result);

    const expected = [_]u16{ 0xD83D, 0xDCA9, 'a' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "codePointSubstringByPositions - basic" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try codePointSubstringByPositions(allocator, &input, 1, 4);
    defer allocator.free(result);

    const expected = [_]u16{ 'e', 'l', 'l' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "codePointSubstringToEnd - basic" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try codePointSubstringToEnd(allocator, &input, 2);
    defer allocator.free(result);

    const expected = [_]u16{ 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "codePointSubstringToEnd - start beyond end returns empty" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'i' };
    const result = try codePointSubstringToEnd(allocator, &input, 10);
    defer allocator.free(result);

    try std.testing.expectEqualSlices(u16, &[_]u16{}, result);
}

test "codePointSubstringToEnd - start at end returns empty" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'i' };
    const result = try codePointSubstringToEnd(allocator, &input, 2);
    defer allocator.free(result);

    try std.testing.expectEqualSlices(u16, &[_]u16{}, result);
}

test "isCodeUnitPrefix - valid prefix" {
    const prefix = [_]u16{ 'h', 'e', 'l' };
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(isCodeUnitPrefix(&prefix, &input));
}

test "isCodeUnitPrefix - not a prefix" {
    const prefix = [_]u16{ 'w', 'o', 'r' };
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(!isCodeUnitPrefix(&prefix, &input));
}

test "isCodeUnitSuffix - valid suffix" {
    const suffix = [_]u16{ 'l', 'l', 'o' };
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(isCodeUnitSuffix(&suffix, &input));
}

test "isCodeUnitSuffix - not a suffix" {
    const suffix = [_]u16{ 'a', 'b', 'c' };
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(!isCodeUnitSuffix(&suffix, &input));
}

test "codeUnitLessThan - less than" {
    const a = [_]u16{ 'a', 'b', 'c' };
    const b = [_]u16{ 'a', 'b', 'd' };
    try std.testing.expect(codeUnitLessThan(&a, &b));
}

test "codeUnitLessThan - with prefix" {
    const a = [_]u16{ 'h', 'e', 'l' };
    const b = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(codeUnitLessThan(&a, &b));
}

test "codeUnitSubstring - basic" {
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = codeUnitSubstring(&input, 1, 3);

    const expected = [_]u16{ 'e', 'l', 'l' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "codeUnitSubstringByPositions - basic" {
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = codeUnitSubstringByPositions(&input, 1, 4);

    const expected = [_]u16{ 'e', 'l', 'l' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "codeUnitSubstringToEnd - basic" {
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = codeUnitSubstringToEnd(&input, 2);

    const expected = [_]u16{ 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "convertToScalarValueString - no surrogates" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try convertToScalarValueString(allocator, &input);
    defer allocator.free(result);

    try std.testing.expectEqualSlices(u16, &input, result);
}

test "convertToScalarValueString - unpaired surrogate" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 0xD800, 'i' };
    const result = try convertToScalarValueString(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 0xFFFD, 'i' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "convertToScalarValueString - valid surrogate pair" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 0xD83D, 0xDCA9, 'a' };
    const result = try convertToScalarValueString(allocator, &input);
    defer allocator.free(result);

    try std.testing.expectEqualSlices(u16, &input, result);
}

test "stripAndCollapseAsciiWhitespace - multiple spaces" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', ' ', ' ', ' ', 'l', 'l', 'o' };
    const result = try stripAndCollapseAsciiWhitespace(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', ' ', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "stripAndCollapseAsciiWhitespace - leading and trailing" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ ' ', 'h', 'i', ' ' };
    const result = try stripAndCollapseAsciiWhitespace(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'i' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "asciiEncode - basic" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try asciiEncode(allocator, &input);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("hello", result);
}

test "asciiDecode - basic" {
    const allocator = std.testing.allocator;
    const input = "hello";
    const result = try asciiDecode(allocator, input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "contains - empty needle" {
    const haystack = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const needle = [_]u16{};
    try std.testing.expect(contains(&haystack, &needle));
}

test "contains - single char found" {
    const haystack = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const needle = [_]u16{'l'};
    try std.testing.expect(contains(&haystack, &needle));
}

test "contains - single char not found" {
    const haystack = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const needle = [_]u16{'x'};
    try std.testing.expect(!contains(&haystack, &needle));
}

test "contains - substring found" {
    const haystack = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const needle = [_]u16{ 'e', 'l', 'l' };
    try std.testing.expect(contains(&haystack, &needle));
}

test "contains - substring not found" {
    const haystack = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const needle = [_]u16{ 'w', 'o', 'r' };
    try std.testing.expect(!contains(&haystack, &needle));
}

test "contains - substring at start" {
    const haystack = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const needle = [_]u16{ 'h', 'e' };
    try std.testing.expect(contains(&haystack, &needle));
}

test "contains - substring at end" {
    const haystack = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const needle = [_]u16{ 'l', 'o' };
    try std.testing.expect(contains(&haystack, &needle));
}

test "contains - needle longer than haystack" {
    const haystack = [_]u16{ 'h', 'i' };
    const needle = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(!contains(&haystack, &needle));
}
