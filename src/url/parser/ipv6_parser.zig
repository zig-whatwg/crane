//! IPv6 Parser
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#ipv6-parser
//! Spec Reference: Lines 539-641
//!
//! Parses IPv6 addresses from strings. Supports:
//! - Full notation: 2001:0db8:0000:0000:0000:0000:0000:0001
//! - Compressed notation: 2001:db8::1
//! - IPv4-in-IPv6: ::ffff:192.0.2.1
//! - Loopback: ::1
//! - Unspecified: ::
//!
//! ## Spec Compliance
//!
//! ✅ Full spec compliance with all validation errors
//!
//! ## Usage
//!
//! ```zig
//! const ipv6 = @import("ipv6_parser");
//!
//! // Parse compressed notation
//! const addr = try ipv6.parseIPv6(allocator, "2001:db8::1", &errors);
//! // Result: [8]u16 array
//! ```

const std = @import("std");
const infra = @import("infra");
const validation = @import("validation");

pub const IPv6Error = error{
    InvalidCompression,
    TooManyPieces,
    MultipleCompression,
    InvalidCodePoint,
    TooFewPieces,
    IPv4InIPv6InvalidCodePoint,
    IPv4InIPv6TooManyPieces,
    IPv4InIPv6OutOfRangePart,
    IPv4InIPv6TooFewParts,
    OutOfMemory,
};

/// EOF code point (conceptual)
const EOF: u21 = 0x110000;

/// Pointer for string processing
const Pointer = struct {
    input: []const u8,
    position: usize,

    fn c(self: *const Pointer) u21 {
        if (self.position >= self.input.len) return EOF;
        return self.input[self.position];
    }

    fn remaining(self: *const Pointer) []const u8 {
        if (self.position >= self.input.len) return "";
        return self.input[self.position..];
    }

    fn increment(self: *Pointer) void {
        self.position += 1;
    }

    fn decrement(self: *Pointer, amount: usize) void {
        self.position -= amount;
    }
};

/// Parse IPv6 address (spec lines 539-641)
///
/// Full spec-compliant implementation with all validation errors.
pub fn parseIPv6(
    allocator: std.mem.Allocator,
    input: []const u8,
    errors: ?*infra.List(validation.ValidationError),
) ![8]u16 {
    // Step 1: Let address be a new IPv6 address whose pieces are all 0
    var address = [_]u16{0} ** 8;

    // Step 2: Let pieceIndex be 0
    var piece_index: usize = 0;

    // Step 3: Let compress be null
    var compress: ?usize = null;

    // Step 4: Let pointer be a pointer for input
    var pointer = Pointer{ .input = input, .position = 0 };

    // Step 5: If c is U+003A (:), then:
    if (pointer.c() == ':') {
        // Step 5.1: If remaining does not start with U+003A (:), validation error, return failure
        if (!std.mem.startsWith(u8, pointer.remaining(), "::")) {
            if (errors) |errs| {
                try errs.append(allocator, .{
                    .type = .ipv6_invalid_compression,
                });
            }
            return IPv6Error.InvalidCompression;
        }

        // Step 5.2: Increase pointer by 2
        pointer.increment();
        pointer.increment();

        // Step 5.3: Increase pieceIndex by 1 and then set compress to pieceIndex
        piece_index += 1;
        compress = piece_index;
    }

    // Step 6: While c is not the EOF code point:
    while (pointer.c() != EOF) {
        // Step 6.1: If pieceIndex is 8, validation error, return failure
        if (piece_index == 8) {
            if (errors) |errs| {
                try errs.append(allocator, .{
                    .type = .ipv6_too_many_pieces,
                });
            }
            return IPv6Error.TooManyPieces;
        }

        // Step 6.2: If c is U+003A (:), then:
        if (pointer.c() == ':') {
            // Step 6.2.1: If compress is non-null, validation error, return failure
            if (compress != null) {
                if (errors) |errs| {
                    try errs.append(allocator, .{
                        .type = .ipv6_multiple_compression,
                    });
                }
                return IPv6Error.MultipleCompression;
            }

            // Step 6.2.2: Increase pointer and pieceIndex by 1, set compress to pieceIndex, and then continue
            pointer.increment();
            piece_index += 1;
            compress = piece_index;
            continue;
        }

        // Step 6.3: Let value and length be 0
        var value: u16 = 0;
        var length: usize = 0;

        // Step 6.4: While length is less than 4 and c is an ASCII hex digit
        while (length < 4) {
            const cp = pointer.c();
            if (cp >= 128) break; // Not ASCII
            const byte = @as(u8, @intCast(cp));
            if (!std.ascii.isHex(byte)) break;
            const digit = std.fmt.charToDigit(byte, 16) catch unreachable;
            value = value * 0x10 + digit;
            pointer.increment();
            length += 1;
        }

        // Step 6.5: If c is U+002E (.), then: (IPv4-in-IPv6)
        if (pointer.c() == '.') {
            // Step 6.5.1: If length is 0, validation error, return failure
            if (length == 0) {
                if (errors) |errs| {
                    try errs.append(allocator, .{
                        .type = .ipv4_in_ipv6_invalid_code_point,
                    });
                }
                return IPv6Error.IPv4InIPv6InvalidCodePoint;
            }

            // Step 6.5.2: Decrease pointer by length
            pointer.decrement(length);

            // Step 6.5.3: If pieceIndex is greater than 6, validation error, return failure
            if (piece_index > 6) {
                if (errors) |errs| {
                    try errs.append(allocator, .{
                        .type = .ipv4_in_ipv6_too_many_pieces,
                    });
                }
                return IPv6Error.IPv4InIPv6TooManyPieces;
            }

            // Step 6.5.4: Let numbersSeen be 0
            var numbers_seen: usize = 0;

            // Step 6.5.5: While c is not the EOF code point:
            while (pointer.c() != EOF) {
                // Step 6.5.5.1: Let ipv4Piece be null
                var ipv4_piece: ?u32 = null;

                // Step 6.5.5.2: If numbersSeen is greater than 0, then:
                if (numbers_seen > 0) {
                    // Step 6.5.5.2.1: If c is a U+002E (.) and numbersSeen is less than 4, then increase pointer by 1
                    if (pointer.c() == '.' and numbers_seen < 4) {
                        pointer.increment();
                    }
                    // Step 6.5.5.2.2: Otherwise, validation error, return failure
                    else {
                        if (errors) |errs| {
                            try errs.append(allocator, .{
                                .type = .ipv4_in_ipv6_invalid_code_point,
                            });
                        }
                        return IPv6Error.IPv4InIPv6InvalidCodePoint;
                    }
                }

                // Step 6.5.5.3: If c is not an ASCII digit, validation error, return failure
                const cp_check = pointer.c();
                if (cp_check >= 128 or !std.ascii.isDigit(@as(u8, @intCast(cp_check)))) {
                    if (errors) |errs| {
                        try errs.append(allocator, .{
                            .type = .ipv4_in_ipv6_invalid_code_point,
                        });
                    }
                    return IPv6Error.IPv4InIPv6InvalidCodePoint;
                }

                // Step 6.5.5.4: While c is an ASCII digit:
                while (true) {
                    const cp_digit = pointer.c();
                    if (cp_digit >= 128) break;
                    const byte_digit = @as(u8, @intCast(cp_digit));
                    if (!std.ascii.isDigit(byte_digit)) break;
                    // Step 6.5.5.4.1: Let number be c interpreted as decimal number
                    const number = @as(u32, @intCast(byte_digit - '0'));

                    // Step 6.5.5.4.2: If ipv4Piece is null, then set ipv4Piece to number
                    if (ipv4_piece == null) {
                        ipv4_piece = number;
                    }
                    // Otherwise, if ipv4Piece is 0, validation error, return failure
                    else if (ipv4_piece.? == 0) {
                        if (errors) |errs| {
                            try errs.append(allocator, .{
                                .type = .ipv4_in_ipv6_invalid_code_point,
                            });
                        }
                        return IPv6Error.IPv4InIPv6InvalidCodePoint;
                    }
                    // Otherwise, set ipv4Piece to ipv4Piece × 10 + number
                    else {
                        ipv4_piece = ipv4_piece.? * 10 + number;
                    }

                    // Step 6.5.5.4.3: If ipv4Piece is greater than 255, validation error, return failure
                    if (ipv4_piece.? > 255) {
                        if (errors) |errs| {
                            try errs.append(allocator, .{
                                .type = .ipv4_in_ipv6_out_of_range_part,
                            });
                        }
                        return IPv6Error.IPv4InIPv6OutOfRangePart;
                    }

                    // Step 6.5.5.4.4: Increase pointer by 1
                    pointer.increment();
                }

                // Step 6.5.5.5: Set address[pieceIndex] to address[pieceIndex] × 0x100 + ipv4Piece
                address[piece_index] = address[piece_index] * 0x100 + @as(u16, @intCast(ipv4_piece.?));

                // Step 6.5.5.6: Increase numbersSeen by 1
                numbers_seen += 1;

                // Step 6.5.5.7: If numbersSeen is 2 or 4, then increase pieceIndex by 1
                if (numbers_seen == 2 or numbers_seen == 4) {
                    piece_index += 1;
                }
            }

            // Step 6.5.6: If numbersSeen is not 4, validation error, return failure
            if (numbers_seen != 4) {
                if (errors) |errs| {
                    try errs.append(allocator, .{
                        .type = .ipv4_in_ipv6_too_few_parts,
                    });
                }
                return IPv6Error.IPv4InIPv6TooFewParts;
            }

            // Step 6.5.7: Break
            break;
        }
        // Step 6.6: Otherwise, if c is U+003A (:):
        else if (pointer.c() == ':') {
            // Step 6.6.1: Increase pointer by 1
            pointer.increment();

            // Step 6.6.2: If c is the EOF code point, validation error, return failure
            if (pointer.c() == EOF) {
                if (errors) |errs| {
                    try errs.append(allocator, .{
                        .type = .ipv6_invalid_code_point,
                    });
                }
                return IPv6Error.InvalidCodePoint;
            }
        }
        // Step 6.7: Otherwise, if c is not the EOF code point, validation error, return failure
        else if (pointer.c() != EOF) {
            if (errors) |errs| {
                try errs.append(allocator, .{
                    .type = .ipv6_invalid_code_point,
                });
            }
            return IPv6Error.InvalidCodePoint;
        }

        // Step 6.8: Set address[pieceIndex] to value
        address[piece_index] = value;

        // Step 6.9: Increase pieceIndex by 1
        piece_index += 1;
    }

    // Step 7: If compress is non-null, then:
    if (compress) |comp| {
        // Step 7.1: Let swaps be pieceIndex − compress
        var swaps = piece_index - comp;

        // Step 7.2: Set pieceIndex to 7
        piece_index = 7;

        // Step 7.3: While pieceIndex is not 0 and swaps is greater than 0
        while (piece_index != 0 and swaps > 0) {
            // Swap address[pieceIndex] with address[compress + swaps − 1]
            const temp = address[piece_index];
            address[piece_index] = address[comp + swaps - 1];
            address[comp + swaps - 1] = temp;

            // Decrease both pieceIndex and swaps by 1
            piece_index -= 1;
            swaps -= 1;
        }
    }
    // Step 8: Otherwise, if compress is null and pieceIndex is not 8, validation error, return failure
    else if (piece_index != 8) {
        if (errors) |errs| {
            try errs.append(allocator, .{
                .type = .ipv6_too_few_pieces,
            });
        }
        return IPv6Error.TooFewPieces;
    }

    // Step 9: Return address
    return address;
}

test "ipv6 parser - loopback" {
    const allocator = std.testing.allocator;

    // ::1 = loopback
    const addr = try parseIPv6(allocator, "::1", null);

    try std.testing.expectEqual(@as(u16, 0), addr[0]);
    try std.testing.expectEqual(@as(u16, 0), addr[6]);
    try std.testing.expectEqual(@as(u16, 1), addr[7]);
}

test "ipv6 parser - unspecified" {
    const allocator = std.testing.allocator;

    // :: = all zeros
    const addr = try parseIPv6(allocator, "::", null);

    for (addr) |piece| {
        try std.testing.expectEqual(@as(u16, 0), piece);
    }
}

test "ipv6 parser - compressed" {
    const allocator = std.testing.allocator;

    // 2001:db8::1
    const addr = try parseIPv6(allocator, "2001:db8::1", null);

    try std.testing.expectEqual(@as(u16, 0x2001), addr[0]);
    try std.testing.expectEqual(@as(u16, 0x0db8), addr[1]);
    try std.testing.expectEqual(@as(u16, 0), addr[2]);
    try std.testing.expectEqual(@as(u16, 1), addr[7]);
}

test "ipv6 parser - full notation" {
    const allocator = std.testing.allocator;

    // Full IPv6 address
    const addr = try parseIPv6(allocator, "2001:0db8:0000:0000:0000:0000:0000:0001", null);

    try std.testing.expectEqual(@as(u16, 0x2001), addr[0]);
    try std.testing.expectEqual(@as(u16, 0x0db8), addr[1]);
    try std.testing.expectEqual(@as(u16, 0x0001), addr[7]);
}

test "ipv6 parser - IPv4-in-IPv6" {
    const allocator = std.testing.allocator;

    // ::ffff:192.0.2.1
    const addr = try parseIPv6(allocator, "::ffff:192.0.2.1", null);

    try std.testing.expectEqual(@as(u16, 0), addr[0]);
    try std.testing.expectEqual(@as(u16, 0xffff), addr[5]);
    try std.testing.expectEqual(@as(u16, 0xc000), addr[6]); // 192.0
    try std.testing.expectEqual(@as(u16, 0x0201), addr[7]); // 2.1
}

test "ipv6 parser - invalid compression at end" {
    const allocator = std.testing.allocator;

    // Single : at start without ::
    const result = parseIPv6(allocator, ":1", null);
    try std.testing.expectError(IPv6Error.InvalidCompression, result);
}

test "ipv6 parser - multiple compression" {
    const allocator = std.testing.allocator;

    // Multiple :: not allowed
    const result = parseIPv6(allocator, "::1::2", null);
    try std.testing.expectError(IPv6Error.MultipleCompression, result);
}

test "ipv6 parser - too many pieces" {
    const allocator = std.testing.allocator;

    // 9 pieces
    const result = parseIPv6(allocator, "1:2:3:4:5:6:7:8:9", null);
    try std.testing.expectError(IPv6Error.TooManyPieces, result);
}

test "ipv6 parser - too few pieces" {
    const allocator = std.testing.allocator;

    // Only 7 pieces without compression
    const result = parseIPv6(allocator, "1:2:3:4:5:6:7", null);
    try std.testing.expectError(IPv6Error.TooFewPieces, result);
}

test "ipv6 parser - invalid character" {
    const allocator = std.testing.allocator;

    // Invalid hex character
    const result = parseIPv6(allocator, "::g", null);
    try std.testing.expectError(IPv6Error.InvalidCodePoint, result);
}

test "ipv6 parser - trailing colon" {
    const allocator = std.testing.allocator;

    // Trailing : without another :
    const result = parseIPv6(allocator, "::1:", null);
    try std.testing.expectError(IPv6Error.InvalidCodePoint, result);
}

test "ipv6 parser - IPv4 leading zero" {
    const allocator = std.testing.allocator;

    // Leading zero not allowed in IPv4 decimal
    const result = parseIPv6(allocator, "::ffff:192.0.02.1", null);
    try std.testing.expectError(IPv6Error.IPv4InIPv6InvalidCodePoint, result);
}

test "ipv6 parser - IPv4 out of range" {
    const allocator = std.testing.allocator;

    // 256 is out of range
    const result = parseIPv6(allocator, "::ffff:256.0.2.1", null);
    try std.testing.expectError(IPv6Error.IPv4InIPv6OutOfRangePart, result);
}

test "ipv6 parser - IPv4 too few parts" {
    const allocator = std.testing.allocator;

    // Only 3 parts instead of 4
    const result = parseIPv6(allocator, "::ffff:192.0.2", null);
    try std.testing.expectError(IPv6Error.IPv4InIPv6TooFewParts, result);
}

test "ipv6 parser - IPv4 in wrong position" {
    const allocator = std.testing.allocator;

    // IPv4 can only be in last 2 pieces (pieceIndex must be <= 6)
    const result = parseIPv6(allocator, "1:2:3:4:5:6:7:192.0.2.1", null);
    try std.testing.expectError(IPv6Error.IPv4InIPv6TooManyPieces, result);
}
