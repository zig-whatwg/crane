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

        // Step 3.5 (cont.): "UTF-8 decode without BOM" each - lossy: bytes
        // that are not UTF-8 become U+FFFD, and the parse never fails.
        const name_string = try utf8DecodeWithoutBom(allocator, name_decoded_bytes);
        errdefer allocator.free(name_string);

        const value_string = try utf8DecodeWithoutBom(allocator, value_decoded_bytes);
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

/// Encoding Standard "UTF-8 decode without BOM": the UTF-8 decoder run over
/// `bytes` in replacement mode, with no BOM sniffed or stripped. Returns the
/// scalar values as UTF-8, owned by `allocator`.
///
/// The decoder's error handling is "replacement": each maximal subpart of an
/// ill-formed sequence is one U+FFFD, and the byte that ended it is decoded
/// again as the start of what follows. So it never fails - a strict
/// validation here made `new URL("http://h/?a=%ff")` throw.
///
/// Spec: https://encoding.spec.whatwg.org/#utf-8-decode-without-bom
///       https://encoding.spec.whatwg.org/#utf-8-decoder
fn utf8DecodeWithoutBom(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    // Valid UTF-8 - the common case - decodes to itself.
    if (std.unicode.utf8ValidateSlice(bytes)) return allocator.dupe(u8, bytes);

    const replacement = "\u{FFFD}";
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    // UTF-8 code point, bytes seen, bytes needed, lower and upper boundary.
    var code_point: u21 = 0;
    var bytes_seen: u3 = 0;
    var bytes_needed: u3 = 0;
    var lower: u8 = 0x80;
    var upper: u8 = 0xBF;
    var i: usize = 0;
    while (i < bytes.len) {
        const byte = bytes[i];
        if (bytes_needed == 0) {
            i += 1;
            switch (byte) {
                0x00...0x7F => try out.append(allocator, byte),
                0xC2...0xDF => {
                    bytes_needed = 1;
                    code_point = byte & 0x1F;
                },
                0xE0...0xEF => {
                    if (byte == 0xE0) lower = 0xA0;
                    if (byte == 0xED) upper = 0x9F;
                    bytes_needed = 2;
                    code_point = byte & 0xF;
                },
                0xF0...0xF4 => {
                    if (byte == 0xF0) lower = 0x90;
                    if (byte == 0xF4) upper = 0x8F;
                    bytes_needed = 3;
                    code_point = byte & 0x7;
                },
                else => try out.appendSlice(allocator, replacement),
            }
            continue;
        }
        if (byte < lower or byte > upper) {
            // Not a continuation here: the sequence so far is one U+FFFD,
            // and the byte is decoded again ("restore byte to ioQueue").
            code_point = 0;
            bytes_needed = 0;
            bytes_seen = 0;
            lower = 0x80;
            upper = 0xBF;
            try out.appendSlice(allocator, replacement);
            continue;
        }
        i += 1;
        lower = 0x80;
        upper = 0xBF;
        code_point = (code_point << 6) | (byte & 0x3F);
        bytes_seen += 1;
        if (bytes_seen != bytes_needed) continue;
        var buffer: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(code_point, &buffer) catch unreachable;
        try out.appendSlice(allocator, buffer[0..len]);
        code_point = 0;
        bytes_needed = 0;
        bytes_seen = 0;
    }
    // End of queue with a sequence unfinished: one U+FFFD.
    if (bytes_needed != 0) try out.appendSlice(allocator, replacement);
    return out.toOwnedSlice(allocator);
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
