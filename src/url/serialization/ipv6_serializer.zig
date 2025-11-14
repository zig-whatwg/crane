//! IPv6 Serializer
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#ipv6-serializer
//! Spec Reference: Lines 680-738
//!
//! The IPv6 serializer converts an IPv6 address to compressed notation
//! following RFC 5952 recommendations.
//!
//! ## Usage
//!
//! ```zig
//! const ipv6_serializer = @import("ipv6_serializer");
//!
//! const addr: [8]u16 = .{ 0, 0, 0, 0, 0, 0, 0, 1 }; // ::1
//! const serialized = try ipv6_serializer.serializeIPv6(allocator, addr);
//! defer allocator.free(serialized);
//! // Result: "::1"
//! ```

const std = @import("std");
const infra = @import("infra");

/// Find the longest sequence of zero pieces for compression (spec lines 718-738)
///
/// Returns the index of the first piece in the longest run of zeros,
/// or null if no run is longer than 1 piece.
fn findCompressedPieceIndex(address: [8]u16) ?usize {
    // Step 1: Let longestIndex be null
    var longest_index: ?usize = null;

    // Step 2: Let longestSize be 1
    var longest_size: usize = 1;

    // Step 3: Let foundIndex be null
    var found_index: ?usize = null;

    // Step 4: Let foundSize be 0
    var found_size: usize = 0;

    // Step 5: For each pieceIndex of address's pieces's indices
    var piece_index: usize = 0;
    while (piece_index < 8) : (piece_index += 1) {
        // Step 5.1: If address's pieces[pieceIndex] is not 0
        if (address[piece_index] != 0) {
            // Step 5.1.1: If foundSize is greater than longestSize
            if (found_size > longest_size) {
                longest_index = found_index;
                longest_size = found_size;
            }

            // Step 5.1.2: Set foundIndex to null
            found_index = null;

            // Step 5.1.3: Set foundSize to 0
            found_size = 0;
        } else {
            // Step 5.2: Otherwise (piece is 0)
            // Step 5.2.1: If foundIndex is null, set foundIndex to pieceIndex
            if (found_index == null) {
                found_index = piece_index;
            }

            // Step 5.2.2: Increment foundSize by 1
            found_size += 1;
        }
    }

    // Step 6: If foundSize is greater than longestSize, return foundIndex
    if (found_size > longest_size) {
        return found_index;
    }

    // Step 7: Return longestIndex
    return longest_index;
}

/// Serialize IPv6 address to compressed notation (spec lines 680-716)
///
/// Takes an IPv6 address as [8]u16 and returns a string in compressed format
/// following RFC 5952 recommendations.
///
/// Example: [0, 0, 0, 0, 0, 0, 0, 1] -> "::1"
pub fn serializeIPv6(allocator: std.mem.Allocator, address: [8]u16) ![]u8 {
    // Step 1: Let output be the empty string
    var output = infra.List(u8).init(allocator);
    errdefer output.deinit();

    // Step 2: Let compress be the result of finding the IPv6 address compressed piece index
    const compress = findCompressedPieceIndex(address);

    // Step 3: Let ignore0 be false
    var ignore0 = false;

    // Step 4: For each pieceIndex of address's pieces's indices
    var piece_index: usize = 0;
    while (piece_index < 8) : (piece_index += 1) {
        // Step 4.1: If ignore0 is true and address[pieceIndex] is 0, then continue
        if (ignore0 and address[piece_index] == 0) {
            continue;
        }

        // Step 4.2: Otherwise, if ignore0 is true, set ignore0 to false
        if (ignore0) {
            ignore0 = false;
        }

        // Step 4.3: If compress is pieceIndex
        if (compress != null and compress.? == piece_index) {
            // Step 4.3.1: Let separator be "::" if pieceIndex is 0; otherwise U+003A (:)
            const separator = if (piece_index == 0) "::" else ":";

            // Step 4.3.2: Append separator to output
            try output.appendSlice(separator);

            // Step 4.3.3: Set ignore0 to true and continue
            ignore0 = true;
            continue;
        }

        // Step 4.4: Append address[pieceIndex], represented as shortest possible lowercase hex
        const piece_str = try std.fmt.allocPrint(allocator, "{x}", .{address[piece_index]});
        defer allocator.free(piece_str);
        try output.appendSlice(piece_str);

        // Step 4.5: If pieceIndex is not 7, then append U+003A (:) to output
        if (piece_index != 7) {
            try output.append(':');
        }
    }

    // Step 5: Return output
    return output.toOwnedSlice();
}

test "ipv6 serializer - loopback" {
    const allocator = std.testing.allocator;

    const addr: [8]u16 = .{ 0, 0, 0, 0, 0, 0, 0, 1 };
    const result = try serializeIPv6(allocator, addr);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("::1", result);
}

test "ipv6 serializer - all zeros" {
    const allocator = std.testing.allocator;

    const addr: [8]u16 = .{ 0, 0, 0, 0, 0, 0, 0, 0 };
    const result = try serializeIPv6(allocator, addr);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("::", result);
}

test "ipv6 serializer - no compression" {
    const allocator = std.testing.allocator;

    const addr: [8]u16 = .{ 0x2001, 0xdb8, 0x1234, 0x5678, 0x9abc, 0xdef0, 0x1234, 0x5678 };
    const result = try serializeIPv6(allocator, addr);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("2001:db8:1234:5678:9abc:def0:1234:5678", result);
}

test "ipv6 serializer - leading zeros compression" {
    const allocator = std.testing.allocator;

    const addr: [8]u16 = .{ 0, 0, 0, 0, 0, 0, 0xc0a8, 0x101 };
    const result = try serializeIPv6(allocator, addr);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("::c0a8:101", result);
}

test "ipv6 serializer - middle zeros compression" {
    const allocator = std.testing.allocator;

    const addr: [8]u16 = .{ 0x2001, 0xdb8, 0, 0, 0, 0, 0x1234, 0x5678 };
    const result = try serializeIPv6(allocator, addr);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("2001:db8::1234:5678", result);
}

test "ipv6 serializer - trailing zeros compression" {
    const allocator = std.testing.allocator;

    const addr: [8]u16 = .{ 0x2001, 0xdb8, 0x1234, 0x5678, 0, 0, 0, 0 };
    const result = try serializeIPv6(allocator, addr);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("2001:db8:1234:5678::", result);
}

test "ipv6 serializer - multiple zero runs, compress longest" {
    const allocator = std.testing.allocator;

    // Two runs of zeros: [2] and [5,6,7] - should compress the longer one
    const addr: [8]u16 = .{ 0x2001, 0xdb8, 0, 0x1234, 0x5678, 0, 0, 0 };
    const result = try serializeIPv6(allocator, addr);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("2001:db8:0:1234:5678::", result);
}

test "ipv6 serializer - find compressed piece index" {
    // No compression (no run > 1)
    const addr1: [8]u16 = .{ 1, 2, 3, 4, 5, 6, 7, 8 };
    try std.testing.expect(findCompressedPieceIndex(addr1) == null);

    // Single zero (no compression, need > 1)
    const addr2: [8]u16 = .{ 1, 0, 3, 4, 5, 6, 7, 8 };
    try std.testing.expect(findCompressedPieceIndex(addr2) == null);

    // Run of 2 zeros at start
    const addr3: [8]u16 = .{ 0, 0, 3, 4, 5, 6, 7, 8 };
    try std.testing.expectEqual(@as(usize, 0), findCompressedPieceIndex(addr3).?);

    // Run of 3 zeros in middle
    const addr4: [8]u16 = .{ 1, 2, 0, 0, 0, 6, 7, 8 };
    try std.testing.expectEqual(@as(usize, 2), findCompressedPieceIndex(addr4).?);

    // All zeros
    const addr5: [8]u16 = .{ 0, 0, 0, 0, 0, 0, 0, 0 };
    try std.testing.expectEqual(@as(usize, 0), findCompressedPieceIndex(addr5).?);
}
