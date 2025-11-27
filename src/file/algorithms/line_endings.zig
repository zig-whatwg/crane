//! W3C File API - Line Endings Conversion
//!
//! This module implements the `convert line endings to native` algorithm
//! per W3C File API spec §3.1.
//!
//! Spec: https://www.w3.org/TR/FileAPI/#constructorBlob
//!
//! ## Platform Line Endings
//!
//! - Windows: CRLF (\r\n)
//! - Unix/Linux/macOS: LF (\n)
//!
//! ## Conversion Rules
//!
//! Per spec, the algorithm normalizes all line endings to the native format:
//! - \n -> native
//! - \r\n -> native
//! - \r (not followed by \n) -> native

const std = @import("std");
const builtin = @import("builtin");

/// The native line ending for the current platform.
pub const NATIVE_LINE_ENDING: []const u8 = switch (builtin.os.tag) {
    .windows => "\r\n",
    else => "\n",
};

/// Convert line endings to native format per W3C File API spec.
///
/// Converts all line ending styles (\n, \r\n, \r) to the platform's
/// native line ending format.
///
/// Parameters:
/// - input: The source string
/// - output: The destination buffer (must be large enough)
///
/// Returns the number of bytes written to output.
pub fn convertLineEndingsToNative(input: []const u8, output: []u8) usize {
    var read_pos: usize = 0;
    var write_pos: usize = 0;

    while (read_pos < input.len) {
        const c = input[read_pos];

        if (c == '\r') {
            // Check for \r\n (CRLF)
            if (read_pos + 1 < input.len and input[read_pos + 1] == '\n') {
                // \r\n -> native
                @memcpy(output[write_pos..][0..NATIVE_LINE_ENDING.len], NATIVE_LINE_ENDING);
                write_pos += NATIVE_LINE_ENDING.len;
                read_pos += 2; // Skip both \r and \n
            } else {
                // Lone \r -> native
                @memcpy(output[write_pos..][0..NATIVE_LINE_ENDING.len], NATIVE_LINE_ENDING);
                write_pos += NATIVE_LINE_ENDING.len;
                read_pos += 1;
            }
        } else if (c == '\n') {
            // \n -> native
            @memcpy(output[write_pos..][0..NATIVE_LINE_ENDING.len], NATIVE_LINE_ENDING);
            write_pos += NATIVE_LINE_ENDING.len;
            read_pos += 1;
        } else {
            // Regular character
            output[write_pos] = c;
            write_pos += 1;
            read_pos += 1;
        }
    }

    return write_pos;
}

/// Convert line endings and return a newly allocated string.
pub fn convertLineEndingsToNativeAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    // Calculate maximum possible size (all characters could be line endings)
    const max_size = input.len * NATIVE_LINE_ENDING.len;

    var output = try allocator.alloc(u8, max_size);
    errdefer allocator.free(output);

    const written = convertLineEndingsToNative(input, output);

    // Shrink to actual size
    output = try allocator.realloc(output, written);

    return output;
}

test "line endings - no conversion needed" {
    var output: [100]u8 = undefined;

    const input = "Hello World";
    const written = convertLineEndingsToNative(input, &output);

    try std.testing.expectEqualStrings("Hello World", output[0..written]);
}

test "line endings - LF to native" {
    var output: [100]u8 = undefined;

    const input = "Line1\nLine2\nLine3";
    const written = convertLineEndingsToNative(input, &output);

    const expected = "Line1" ++ NATIVE_LINE_ENDING ++ "Line2" ++ NATIVE_LINE_ENDING ++ "Line3";
    try std.testing.expectEqualStrings(expected, output[0..written]);
}

test "line endings - CRLF to native" {
    var output: [100]u8 = undefined;

    const input = "Line1\r\nLine2\r\nLine3";
    const written = convertLineEndingsToNative(input, &output);

    const expected = "Line1" ++ NATIVE_LINE_ENDING ++ "Line2" ++ NATIVE_LINE_ENDING ++ "Line3";
    try std.testing.expectEqualStrings(expected, output[0..written]);
}

test "line endings - lone CR to native" {
    var output: [100]u8 = undefined;

    const input = "Line1\rLine2\rLine3";
    const written = convertLineEndingsToNative(input, &output);

    const expected = "Line1" ++ NATIVE_LINE_ENDING ++ "Line2" ++ NATIVE_LINE_ENDING ++ "Line3";
    try std.testing.expectEqualStrings(expected, output[0..written]);
}

test "line endings - mixed endings" {
    var output: [100]u8 = undefined;

    const input = "A\nB\r\nC\rD";
    const written = convertLineEndingsToNative(input, &output);

    const expected = "A" ++ NATIVE_LINE_ENDING ++ "B" ++ NATIVE_LINE_ENDING ++ "C" ++ NATIVE_LINE_ENDING ++ "D";
    try std.testing.expectEqualStrings(expected, output[0..written]);
}

test "line endings - empty string" {
    var output: [100]u8 = undefined;

    const input = "";
    const written = convertLineEndingsToNative(input, &output);

    try std.testing.expectEqual(@as(usize, 0), written);
}

test "line endings - only line endings" {
    var output: [100]u8 = undefined;

    const input = "\n\r\n\r";
    const written = convertLineEndingsToNative(input, &output);

    const expected = NATIVE_LINE_ENDING ++ NATIVE_LINE_ENDING ++ NATIVE_LINE_ENDING;
    try std.testing.expectEqualStrings(expected, output[0..written]);
}

test "line endings - alloc version" {
    const allocator = std.testing.allocator;

    const result = try convertLineEndingsToNativeAlloc(allocator, "A\nB\r\nC");
    defer allocator.free(result);

    const expected = "A" ++ NATIVE_LINE_ENDING ++ "B" ++ NATIVE_LINE_ENDING ++ "C";
    try std.testing.expectEqualStrings(expected, result);
}
