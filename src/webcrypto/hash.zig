//! WebCrypto §32: SHA-1 and SHA-2 digest operations.

const std = @import("std");

/// The four hash functions registered for the digest operation.
pub const Hash = enum {
    sha1,
    sha256,
    sha384,
    sha512,

    /// The canonical WebCrypto algorithm name.
    pub fn name(self: Hash) []const u8 {
        return switch (self) {
            .sha1 => "SHA-1",
            .sha256 => "SHA-256",
            .sha384 => "SHA-384",
            .sha512 => "SHA-512",
        };
    }

    /// Resolve a digest name using the §18.4.4 ASCII-insensitive match.
    pub fn fromName(name_value: []const u8) error{NotSupportedError}!Hash {
        inline for (std.meta.tags(Hash)) |candidate| {
            if (std.ascii.eqlIgnoreCase(name_value, candidate.name())) return candidate;
        }
        return error.NotSupportedError;
    }

    pub fn Implementation(comptime self: Hash) type {
        return switch (self) {
            .sha1 => std.crypto.hash.Sha1,
            .sha256 => std.crypto.hash.sha2.Sha256,
            .sha384 => std.crypto.hash.sha2.Sha384,
            .sha512 => std.crypto.hash.sha2.Sha512,
        };
    }

    pub fn digestLength(self: Hash) usize {
        return switch (self) {
            inline else => |value| value.Implementation().digest_length,
        };
    }

    pub fn blockLength(self: Hash) usize {
        return switch (self) {
            inline else => |value| value.Implementation().block_length,
        };
    }
};

/// Hash a message. The caller owns the returned digest bytes.
pub fn digest(allocator: std.mem.Allocator, hash: Hash, message: []const u8) ![]u8 {
    // §32.3 step 1: perform the selected SHA function; step 2: return digest.
    switch (hash) {
        inline else => |value| {
            const H = value.Implementation();
            const result = try allocator.alloc(u8, H.digest_length);
            H.hash(message, result[0..H.digest_length], .{});
            return result;
        },
    }
}

test "digest algorithm names are ASCII insensitive, without aliases" {
    try std.testing.expectEqual(Hash.sha1, try Hash.fromName("sha-1"));
    try std.testing.expectEqual(Hash.sha256, try Hash.fromName("sHa-256"));
    try std.testing.expectEqual(Hash.sha384, try Hash.fromName("SHA-384"));
    try std.testing.expectEqual(Hash.sha512, try Hash.fromName("sha-512"));
    for ([_][]const u8{ "SHA256", "SHA-224", "SHA-256 ", "AES-GCM", "", "ſHA-1" }) |name| {
        try std.testing.expectError(error.NotSupportedError, Hash.fromName(name));
    }
}

test "SHA digests match the standard empty and abc vectors" {
    const Vector = struct { hash: Hash, input: []const u8, hex: []const u8 };
    // FIPS 180-4 / RFC 6234; empty vectors also appear in WPT digest.https.any.js.
    const vectors = [_]Vector{
        .{ .hash = .sha1, .input = "", .hex = "da39a3ee5e6b4b0d3255bfef95601890afd80709" },
        .{ .hash = .sha1, .input = "abc", .hex = "a9993e364706816aba3e25717850c26c9cd0d89d" },
        .{ .hash = .sha256, .input = "", .hex = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" },
        .{ .hash = .sha256, .input = "abc", .hex = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" },
        .{ .hash = .sha384, .input = "", .hex = "38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b" },
        .{ .hash = .sha384, .input = "abc", .hex = "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7" },
        .{ .hash = .sha512, .input = "", .hex = "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e" },
        .{ .hash = .sha512, .input = "abc", .hex = "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f" },
    };
    for (vectors) |vector| {
        const result = try digest(std.testing.allocator, vector.hash, vector.input);
        defer std.testing.allocator.free(result);
        var expected: [64]u8 = undefined;
        const bytes = try std.fmt.hexToBytes(&expected, vector.hex);
        try std.testing.expectEqualSlices(u8, bytes, result);
    }
}

test "digest propagates allocation failures" {
    try std.testing.expectError(error.OutOfMemory, digest(std.testing.failing_allocator, .sha256, "abc"));
}
