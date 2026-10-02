//! WebCrypto §31.6.1-2: HMAC generation and constant-time verification.

const std = @import("std");
const Hash = @import("hash.zig").Hash;

/// Return a MAC allocated with `allocator`.
pub fn sign(allocator: std.mem.Allocator, hash: Hash, key: []const u8, message: []const u8) ![]u8 {
    // §31.6.1 steps 1-2: HMAC with the key's hash and complete key material.
    switch (hash) {
        inline else => |value| {
            const H = std.crypto.auth.hmac.Hmac(value.Implementation());
            const result = try allocator.alloc(u8, H.mac_length);
            var context = H.init(key);
            defer std.crypto.secureZero(u8, std.mem.asBytes(&context));
            context.update(message);
            context.final(result[0..H.mac_length]);
            return result;
        },
    }
}

/// Compare the complete MAC; short and long signatures never match.
pub fn verify(hash: Hash, key: []const u8, signature: []const u8, message: []const u8) bool {
    // §31.6.2 steps 1-2: recompute the whole MAC, then compare in constant time.
    switch (hash) {
        inline else => |value| {
            const H = std.crypto.auth.hmac.Hmac(value.Implementation());
            if (signature.len != H.mac_length) return false;
            var expected: [H.mac_length]u8 = undefined;
            defer std.crypto.secureZero(u8, &expected);
            var context = H.init(key);
            defer std.crypto.secureZero(u8, std.mem.asBytes(&context));
            context.update(message);
            context.final(&expected);
            return std.crypto.timing_safe.eql([H.mac_length]u8, expected, signature[0..H.mac_length].*);
        },
    }
}

test "HMAC matches RFC 2202 and RFC 4231 case 1 for every registered hash" {
    const vectors = .{
        .{ Hash.sha1, "b617318655057264e28bc0b6fb378c8ef146be00" },
        .{ Hash.sha256, "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7" },
        .{ Hash.sha384, "afd03944d84895626b0825f4ab46907f15f9dadbe4101ec682aa034c7cebc59cfaea9ea9076ede7f4af152e8b2fa9cb6" },
        .{ Hash.sha512, "87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cdedaa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854" },
    };
    const key = [_]u8{0x0b} ** 20;
    inline for (vectors) |vector| {
        var expected_storage: [64]u8 = undefined;
        const expected = try std.fmt.hexToBytes(&expected_storage, vector[1]);
        const actual = try sign(std.testing.allocator, vector[0], &key, "Hi There");
        defer std.testing.allocator.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
        try std.testing.expect(verify(vector[0], &key, expected, "Hi There"));
        try std.testing.expect(!verify(vector[0], &key, expected[1..], "Hi There"));
        try std.testing.expect(!verify(vector[0], &key, expected, "Hi there"));
        for (0..expected.len) |index| {
            expected[index] ^= 1;
            try std.testing.expect(!verify(vector[0], &key, expected, "Hi There"));
            expected[index] ^= 1;
        }
    }
}

test "HMAC hashes a key longer than the hash block" {
    // RFC 4231 case 6.
    const key = [_]u8{0xaa} ** 131;
    const actual = try sign(std.testing.allocator, .sha256, &key, "Test Using Larger Than Block-Size Key - Hash Key First");
    defer std.testing.allocator.free(actual);
    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54");
    try std.testing.expectEqualSlices(u8, &expected, actual);
}

test "HMAC propagates allocation failure" {
    try std.testing.expectError(error.OutOfMemory, sign(std.testing.failing_allocator, .sha256, "key", "message"));
}
