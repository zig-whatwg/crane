//! WebCrypto §10.1: cryptographically secure random bytes and UUIDs.

const std = @import("std");

/// Fill with operating-system entropy; failure never falls back to a PRNG.
pub fn fill(io: std.Io, bytes: []u8) !void {
    // §10.1.1 step 5; §10.1.2 step 2. Zig 0.16's Io.randomSecure is
    // the standard library's non-fallback source of secure entropy.
    try io.randomSecure(bytes);
}

/// Format 16 random bytes as a lowercase version-4 UUID. Caller owns the text.
pub fn formatUuid(allocator: std.mem.Allocator, bytes: [16]u8) ![]u8 {
    var value = bytes;
    // §10.1.2 steps 3-4: preserve all bits except version and variant.
    value[6] = (value[6] & 0x0f) | 0x40;
    value[8] = (value[8] & 0x3f) | 0x80;
    // Step 5: two lowercase hexadecimal digits per byte, with hyphens.
    const result = try allocator.alloc(u8, 36);
    const hex = "0123456789abcdef";
    var offset: usize = 0;
    for (value, 0..) |byte, index| {
        if (index == 4 or index == 6 or index == 8 or index == 10) {
            result[offset] = '-';
            offset += 1;
        }
        result[offset] = hex[byte >> 4];
        result[offset + 1] = hex[byte & 0x0f];
        offset += 2;
    }
    return result;
}

/// Generate a UUID with the supplied entropy source. Caller owns the text.
pub fn uuid(io: std.Io, allocator: std.mem.Allocator) ![]u8 {
    // §10.1.2 steps 1-2, followed by the version/variant and text steps.
    var bytes: [16]u8 = undefined;
    try fill(io, &bytes);
    return formatUuid(allocator, bytes);
}

test "UUID preserves random bits, sets version and variant, and pads hex" {
    const bytes = [16]u8{ 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0xf6, 0x07, 0xff, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f };
    const result = try formatUuid(std.testing.allocator, bytes);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("00010203-0405-4607-bf09-0a0b0c0d0e0f", result);
}

test "UUID allocation failure is propagated without leaks" {
    try std.testing.expectError(error.OutOfMemory, formatUuid(std.testing.failing_allocator, @splat(0)));
}

test "entropy failure rejects random bytes and UUIDs" {
    var bytes: [16]u8 = @splat(0x55);
    try std.testing.expectError(error.EntropyUnavailable, fill(std.Io.failing, &bytes));
    try std.testing.expectError(error.EntropyUnavailable, uuid(std.Io.failing, std.testing.allocator));
}
