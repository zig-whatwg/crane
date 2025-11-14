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
const infra = @import("infra");

/// Serialize IPv4 address to dotted-decimal notation (spec lines 664-678)
///
/// Takes an IPv4 address as a u32 and returns a string in dotted-decimal format.
///
/// Example: 0xC0A80101 -> "192.168.1.1"
pub fn serializeIPv4(allocator: std.mem.Allocator, address: u32) ![]u8 {
    // Step 1: Let output be the empty string
    var output = infra.List(u8).init(allocator);
    errdefer output.deinit();

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
        try output.insertSlice(0, octet_str);

        // Step 3.2: If i is not 4, then prepend U+002E (.) to output
        if (i != 4) {
            try output.insert(0, '.');
        }

        // Step 3.3: Set n to floor(n / 256)
        n = n / 256;
    }

    // Step 4: Return output
    return output.toOwnedSlice();
}





