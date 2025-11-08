//! IPv4 Serializer
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#ipv4-serializer
//! Spec Reference: Lines 664-678
//!
//! The IPv4 serializer converts an IPv4 address (u32) to dotted-decimal notation.
//!
//! ## Usage
//!
//! ```zig
//! const ipv4_serializer = @import("ipv4_serializer");
//!
//! const serialized = try ipv4_serializer.serializeIPv4(allocator, 0xC0A80101);
//! defer allocator.free(serialized);
//! // Result: "192.168.1.1"
//! ```

const std = @import("std");

/// Serialize IPv4 address to dotted-decimal notation (spec lines 664-678)
///
/// Takes an IPv4 address as a u32 and returns a string in dotted-decimal format.
///
/// Example: 0xC0A80101 -> "192.168.1.1"
pub fn serializeIPv4(allocator: std.mem.Allocator, address: u32) ![]u8 {
    // Step 1: Let output be the empty string
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    // Step 2: Let n be the value of address
    var n = address;

    // Step 3: For each i in the range 1 to 4, inclusive
    var i: u8 = 1;
    while (i <= 4) : (i += 1) {
        // Step 3.1: Prepend n % 256, serialized, to output
        const octet = n % 256;
        const octet_str = try std.fmt.allocPrint(allocator, "{d}", .{octet});
        defer allocator.free(octet_str);

        // Prepend octet to output
        try output.insertSlice(allocator, 0, octet_str);

        // Step 3.2: If i is not 4, then prepend U+002E (.) to output
        if (i != 4) {
            try output.insert(allocator, 0, '.');
        }

        // Step 3.3: Set n to floor(n / 256)
        n = n / 256;
    }

    // Step 4: Return output
    return output.toOwnedSlice(allocator);
}

test "ipv4 serializer - basic" {
    const allocator = std.testing.allocator;

    const result = try serializeIPv4(allocator, 0xC0A80101);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("192.168.1.1", result);
}

test "ipv4 serializer - localhost" {
    const allocator = std.testing.allocator;

    const result = try serializeIPv4(allocator, 0x7F000001);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("127.0.0.1", result);
}

test "ipv4 serializer - zero" {
    const allocator = std.testing.allocator;

    const result = try serializeIPv4(allocator, 0x00000000);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("0.0.0.0", result);
}

test "ipv4 serializer - max" {
    const allocator = std.testing.allocator;

    const result = try serializeIPv4(allocator, 0xFFFFFFFF);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("255.255.255.255", result);
}

test "ipv4 serializer - google dns" {
    const allocator = std.testing.allocator;

    const result = try serializeIPv4(allocator, 0x08080808);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("8.8.8.8", result);
}
