//! WebCrypto §33.4.1 and §34.4.1: HKDF and PBKDF2 derivation.

const std = @import("std");
const Hash = @import("hash.zig").Hash;

/// Derive `length` bits, rejecting absent/non-byte lengths per WebCrypto.
pub fn hkdf(allocator: std.mem.Allocator, hash: Hash, key: []const u8, salt: []const u8, info: []const u8, length: ?u32) ![]u8 {
    // §33.4.1 step 1: only a present, byte-aligned length is accepted.
    const bits = length orelse return error.OperationError;
    if (bits % 8 != 0) return error.OperationError;
    // Steps 2-6: RFC 5869's output bound, key material, extract, and expand.
    if (bits / 8 > 255 * hash.digestLength()) return error.OperationError;
    const result = try allocator.alloc(u8, bits / 8);
    switch (hash) {
        inline else => |value| {
            const H = std.crypto.kdf.hkdf.Hkdf(std.crypto.auth.hmac.Hmac(value.Implementation()));
            var prk = H.extract(salt, key);
            defer std.crypto.secureZero(u8, &prk);
            H.expand(result, info, prk);
        },
    }
    // Step 7: return the derived bytes.
    return result;
}

/// Derive `length` bits with the exact requested positive iteration count.
pub fn pbkdf2(allocator: std.mem.Allocator, hash: Hash, password: []const u8, salt: []const u8, iterations: u32, length: ?u32) ![]u8 {
    // §34.4.1 steps 1-3: validate length and iterations before the empty result.
    const bits = length orelse return error.OperationError;
    if (bits % 8 != 0 or iterations == 0) return error.OperationError;
    const result = try allocator.alloc(u8, bits / 8);
    errdefer {
        std.crypto.secureZero(u8, result);
        allocator.free(result);
    }
    if (bits == 0) return result;
    // Steps 4-6: use the selected HMAC as the PRF, mapping derivation failure.
    switch (hash) {
        inline else => |value| std.crypto.pwhash.pbkdf2(result, password, salt, iterations, std.crypto.auth.hmac.Hmac(value.Implementation())) catch return error.OperationError,
    }
    // Step 7: return the derived bytes.
    return result;
}

test "HKDF matches RFC 5869 SHA-256 case 1" {
    const key = [_]u8{0x0b} ** 22;
    const salt = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
    const info = [_]u8{ 0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9 };
    const actual = try hkdf(std.testing.allocator, .sha256, &key, &salt, &info, 42 * 8);
    defer std.testing.allocator.free(actual);
    var expected: [42]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865");
    try std.testing.expectEqualSlices(u8, &expected, actual);
}

test "HKDF matches RFC 5869 SHA-1 case 4" {
    const key = [_]u8{0x0b} ** 11;
    const salt = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
    const info = [_]u8{ 0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9 };
    const actual = try hkdf(std.testing.allocator, .sha1, &key, &salt, &info, 42 * 8);
    defer std.testing.allocator.free(actual);
    var expected: [42]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "085a01ea1b10f36933068b56efa5ad81a4f14b822f5b091568a9cdd4f155fda2c22e422478d305f3f896");
    try std.testing.expectEqualSlices(u8, &expected, actual);
}

test "PBKDF2 matches RFC 6070 including embedded NUL octets" {
    const vectors = .{
        .{ "password", "salt", @as(u32, 1), @as(u32, 20), "0c60c80f961f0e71f3a9b524af6012062fe037a6" },
        .{ "password", "salt", @as(u32, 2), @as(u32, 20), "ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957" },
        .{ "pass\x00word", "sa\x00lt", @as(u32, 4096), @as(u32, 16), "56fa6aa75548099dcc37d7f03425e0c3" },
    };
    inline for (vectors) |vector| {
        const actual = try pbkdf2(std.testing.allocator, .sha1, vector[0], vector[1], vector[2], vector[3] * 8);
        defer std.testing.allocator.free(actual);
        var expected_storage: [20]u8 = undefined;
        const expected = try std.fmt.hexToBytes(&expected_storage, vector[4]);
        try std.testing.expectEqualSlices(u8, expected, actual);
    }
}

test "KDFs validate lengths and iterations before allocation" {
    const fail = std.testing.failing_allocator;
    for ([_]?u32{ null, 1, 9 }) |length| {
        try std.testing.expectError(error.OperationError, hkdf(fail, .sha256, "", "", "", length));
        try std.testing.expectError(error.OperationError, pbkdf2(fail, .sha256, "", "", 1, length));
    }
    try std.testing.expectError(error.OperationError, hkdf(fail, .sha256, "", "", "", 256 * 32 * 8));
    try std.testing.expectError(error.OperationError, pbkdf2(fail, .sha256, "", "", 0, 0));
    try std.testing.expectError(error.OutOfMemory, hkdf(fail, .sha256, "", "", "", 8));
    try std.testing.expectError(error.OutOfMemory, pbkdf2(fail, .sha256, "", "", 1, 8));
}

test "both KDFs return empty output for zero bits" {
    const h = try hkdf(std.testing.allocator, .sha512, "key", "salt", "", 0);
    defer std.testing.allocator.free(h);
    const p = try pbkdf2(std.testing.allocator, .sha384, "password", "salt", 1, 0);
    defer std.testing.allocator.free(p);
    try std.testing.expectEqual(@as(usize, 0), h.len);
    try std.testing.expectEqual(@as(usize, 0), p.len);
}
