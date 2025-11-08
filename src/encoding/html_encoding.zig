//! HTML Error Mode Encoding
//!
//! WHATWG Encoding Standard §4.1
//! https://encoding.spec.whatwg.org/#error-mode
//!
//! When error mode is "html", unencodable characters are emitted as
//! HTML numeric character references: &#NNNN;

const std = @import("std");
const io_queue = @import("io_queue.zig");
const ByteQueue = io_queue.ByteQueue;

/// Encode a code point as HTML numeric character reference
///
/// Spec §4.1: Push 0x26 (&), 0x23 (#), followed by the shortest sequence
/// of 0x30 (0) to 0x39 (9), inclusive, representing result's code point's
/// value in base ten, followed by 0x3B (;) to output.
///
/// Example: U+06DE → &#1758;
pub fn encodeAsHtmlEntity(code_point: u21, output: *ByteQueue) !void {
    // Push '&' (0x26)
    try output.push(0x26);

    // Push '#' (0x23)
    try output.push(0x23);

    // Convert code point to decimal digits
    var buffer: [10]u8 = undefined;
    const digits = std.fmt.bufPrint(&buffer, "{d}", .{code_point}) catch unreachable;

    // Push each digit (0x30-0x39)
    for (digits) |digit| {
        try output.push(digit);
    }

    // Push ';' (0x3B)
    try output.push(0x3B);
}

/// Encode a code point as HTML entity to a byte slice
///
/// Returns the number of bytes written
pub fn encodeAsHtmlEntityToSlice(code_point: u21, output: []u8) !usize {
    var pos: usize = 0;

    if (output.len < 2) return error.OutputBufferTooSmall;

    // Write '&#'
    output[pos] = 0x26; // '&'
    pos += 1;
    output[pos] = 0x23; // '#'
    pos += 1;

    // Convert code point to decimal digits
    var buffer: [10]u8 = undefined;
    const digits = std.fmt.bufPrint(&buffer, "{d}", .{code_point}) catch unreachable;

    if (pos + digits.len + 1 > output.len) return error.OutputBufferTooSmall;

    // Write digits
    for (digits) |digit| {
        output[pos] = digit;
        pos += 1;
    }

    // Write ';'
    output[pos] = 0x3B; // ';'
    pos += 1;

    return pos;
}

/// Calculate the maximum bytes needed for an HTML entity
///
/// U+10FFFF → &#1114111; = 10 bytes
pub fn maxHtmlEntityBytes() usize {
    return 10; // "&#" + max 7 digits + ";"
}

// Tests

test "HTML entity encoding - simple" {
    const allocator = std.testing.allocator;

    var output = ByteQueue.init(allocator);
    defer output.deinit();

    // Encode U+0041 ('A') as &#65;
    try encodeAsHtmlEntity(0x0041, &output);

    const result = try output.toSlice(allocator);
    defer allocator.free(result);

    const expected = "&#65;";
    try std.testing.expectEqualStrings(expected, result);
}

test "HTML entity encoding - Arabic letter" {
    const allocator = std.testing.allocator;

    var output = ByteQueue.init(allocator);
    defer output.deinit();

    // Encode U+06DE (Arabic letter) as &#1758;
    try encodeAsHtmlEntity(0x06DE, &output);

    const result = try output.toSlice(allocator);
    defer allocator.free(result);

    const expected = "&#1758;";
    try std.testing.expectEqualStrings(expected, result);
}

test "HTML entity encoding - max code point" {
    const allocator = std.testing.allocator;

    var output = ByteQueue.init(allocator);
    defer output.deinit();

    // Encode U+10FFFF as &#1114111;
    try encodeAsHtmlEntity(0x10FFFF, &output);

    const result = try output.toSlice(allocator);
    defer allocator.free(result);

    const expected = "&#1114111;";
    try std.testing.expectEqualStrings(expected, result);
}

test "HTML entity encoding to slice" {
    var buffer: [20]u8 = undefined;

    // Encode U+06DE
    const len = try encodeAsHtmlEntityToSlice(0x06DE, &buffer);

    const expected = "&#1758;";
    try std.testing.expectEqualStrings(expected, buffer[0..len]);
}

test "HTML entity encoding to slice - buffer too small" {
    var buffer: [4]u8 = undefined;

    // Should fail - need at least 5 bytes for &#65; but only have 4
    const result = encodeAsHtmlEntityToSlice(0x0041, &buffer);
    try std.testing.expectError(error.OutputBufferTooSmall, result);
}

test "max HTML entity bytes" {
    try std.testing.expectEqual(@as(usize, 10), maxHtmlEntityBytes());
}
