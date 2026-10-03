//! WebCrypto §§23–24: NIST elliptic-curve operations on owned native bytes.

const std = @import("std");
const Curve = @import("key.zig").Curve;
const Hash = @import("hash.zig").Hash;
const mbed = @import("mbed.zig");
const c = mbed.c;

pub fn byteLength(curve: Curve) usize {
    return switch (curve) {
        .p256 => 32,
        .p384 => 48,
        .p521 => 66,
    };
}

fn Implementation(comptime curve: Curve) type {
    return switch (curve) {
        .p256 => std.crypto.ecc.P256,
        .p384 => std.crypto.ecc.P384,
        .p521 => unreachable,
    };
}

pub fn generateSecret(allocator: std.mem.Allocator, io: std.Io, curve: Curve) ![]u8 {
    // §§23.7.3/24.4.1 step 2: choose a scalar uniformly from [1, order-1].
    switch (curve) {
        .p521 => {
            if (!mbed.available) return error.NotSupportedError;
            var key = try mbed.Key.generateP521();
            defer key.deinit();
            var secret: [66]u8 = undefined;
            defer std.crypto.secureZero(u8, &secret);
            var written: usize = 0;
            try mbed.check(c.psa_export_key(key.id, &secret, secret.len, &written));
            if (written != secret.len) return error.OperationError;
            return allocator.dupe(u8, &secret);
        },
        inline .p256, .p384 => |named| {
            const C = Implementation(named);
            var bytes: [C.scalar.encoded_length]u8 = undefined;
            defer std.crypto.secureZero(u8, &bytes);
            while (true) {
                io.randomSecure(&bytes) catch return error.OperationError;
                var scalar = C.scalar.Scalar.fromBytes(bytes, .big) catch continue;
                defer std.crypto.secureZero(u8, std.mem.asBytes(&scalar));
                if (!scalar.isZero()) return allocator.dupe(u8, &bytes);
            }
        },
    }
}

fn validateScalar(comptime C: type, secret: []const u8) !void {
    if (secret.len != C.scalar.encoded_length) return error.DataError;
    var scalar = C.scalar.Scalar.fromBytes(secret[0..C.scalar.encoded_length].*, .big) catch return error.DataError;
    defer std.crypto.secureZero(u8, std.mem.asBytes(&scalar));
    if (scalar.isZero()) return error.DataError;
}

pub fn publicKey(allocator: std.mem.Allocator, curve: Curve, secret: []const u8) ![]u8 {
    switch (curve) {
        .p521 => return p521Public(allocator, secret, true),
        inline .p256, .p384 => |named| {
            const C = Implementation(named);
            try validateScalar(C, secret);
            // RFC 6090 §4: Q = dG, encoded using SEC 1 §2.3.3.
            const point = C.basePoint.mul(secret[0..C.scalar.encoded_length].*, .big) catch return error.DataError;
            return allocator.dupe(u8, &point.toUncompressedSec1());
        },
    }
}

pub fn normalizePublic(allocator: std.mem.Allocator, curve: Curve, bytes: []const u8) ![]u8 {
    switch (curve) {
        .p521 => return p521Public(allocator, bytes, false),
        inline .p256, .p384 => |named| {
            const C = Implementation(named);
            // §§23.7.4/24.4.3: SEC 1 §2.3.4 decode and §3.2.2 validation.
            const point = C.fromSec1(bytes) catch return error.DataError;
            point.rejectIdentity() catch return error.DataError;
            return allocator.dupe(u8, &point.toUncompressedSec1());
        },
    }
}

pub fn sign(allocator: std.mem.Allocator, io: std.Io, curve: Curve, hash: Hash, secret: []const u8, message: []const u8) ![]u8 {
    switch (curve) {
        .p521 => {
            if (!mbed.available) return error.NotSupportedError;
            // §23.7.1 steps 2–7, using the same fixed-width r || s PSA format.
            const algorithm = c.PSA_ALG_ECDSA(mbed.hashAlgorithm(hash));
            var key = try mbed.Key.importP521(secret, true, algorithm, c.PSA_KEY_USAGE_SIGN_HASH);
            defer key.deinit();
            var digest: [64]u8 = undefined;
            const hashed = hashMessage(hash, message, &digest);
            var signature: [132]u8 = undefined;
            var written: usize = 0;
            try mbed.check(c.psa_sign_hash(key.id, algorithm, hashed.ptr, hashed.len, &signature, signature.len, &written));
            if (written != signature.len) return error.OperationError;
            return allocator.dupe(u8, &signature);
        },
        inline .p256, .p384 => |named| switch (hash) {
            inline else => |digest| {
                const C = Implementation(named);
                const E = std.crypto.sign.ecdsa.Ecdsa(C, digest.Implementation());
                try validateScalar(C, secret);
                var pair = E.KeyPair.fromSecretKey(try E.SecretKey.fromBytes(secret[0..E.SecretKey.encoded_length].*)) catch return error.OperationError;
                defer std.crypto.secureZero(u8, std.mem.asBytes(&pair));
                var noise: [E.noise_length]u8 = undefined;
                defer std.crypto.secureZero(u8, &noise);
                io.randomSecure(&noise) catch return error.OperationError;
                // §23.7.1 steps 2–7: hash, ECDSA, fixed-width big-endian r || s.
                const signature = pair.sign(message, noise) catch return error.OperationError;
                return allocator.dupe(u8, &signature.toBytes());
            },
        },
    }
}

pub fn verify(curve: Curve, hash: Hash, public: []const u8, signature: []const u8, message: []const u8) !bool {
    // §23.7.2 step 6: signatures use exactly two fixed-width integers.
    if (signature.len != 2 * byteLength(curve)) return false;
    switch (curve) {
        .p521 => {
            if (!mbed.available) return error.NotSupportedError;
            const algorithm = c.PSA_ALG_ECDSA(mbed.hashAlgorithm(hash));
            var key = try mbed.Key.importP521(public, false, algorithm, c.PSA_KEY_USAGE_VERIFY_HASH);
            defer key.deinit();
            var digest: [64]u8 = undefined;
            const hashed = hashMessage(hash, message, &digest);
            const status = c.psa_verify_hash(key.id, algorithm, hashed.ptr, hashed.len, signature.ptr, signature.len);
            if (status == c.PSA_ERROR_INVALID_SIGNATURE) return false;
            try mbed.check(status);
            return true;
        },
        inline .p256, .p384 => |named| switch (hash) {
            inline else => |digest| {
                const E = std.crypto.sign.ecdsa.Ecdsa(Implementation(named), digest.Implementation());
                const key = E.PublicKey.fromSec1(public) catch return false;
                key.p.rejectIdentity() catch return false;
                // Steps 2–8: hash and verify the equation; invalid signatures
                // produce false, including out-of-range r and s.
                E.Signature.fromBytes(signature[0..E.Signature.encoded_length].*).verify(message, key) catch return false;
                return true;
            },
        },
    }
}

pub fn derive(allocator: std.mem.Allocator, curve: Curve, secret: []const u8, peer: []const u8, length: ?u32) ![]u8 {
    // §24.4.2 steps 4–5: P-521's encoded field element has 528 bits.
    const bits = length orelse @as(u32, @intCast(8 * byteLength(curve)));
    if (bits > 8 * byteLength(curve)) return error.OperationError;
    switch (curve) {
        .p521 => {
            if (!mbed.available) return error.NotSupportedError;
            var key = try mbed.Key.importP521(secret, true, c.PSA_ALG_ECDH, c.PSA_KEY_USAGE_DERIVE);
            defer key.deinit();
            var shared: [66]u8 = undefined;
            defer std.crypto.secureZero(u8, &shared);
            var written: usize = 0;
            try mbed.check(c.psa_raw_key_agreement(c.PSA_ALG_ECDH, key.id, peer.ptr, peer.len, &shared, shared.len, &written));
            if (written != shared.len) return error.OperationError;
            return truncate(allocator, &shared, bits);
        },
        inline .p256, .p384 => |named| {
            const C = Implementation(named);
            try validateScalar(C, secret);
            const point = C.fromSec1(peer) catch return error.OperationError;
            point.rejectIdentity() catch return error.OperationError;
            // Steps 9–10: RFC 6090's ECDH primitive and field-element encoding.
            var shared_point = point.mul(secret[0..C.scalar.encoded_length].*, .big) catch return error.OperationError;
            defer std.crypto.secureZero(u8, std.mem.asBytes(&shared_point));
            var shared = shared_point.affineCoordinates().x.toBytes(.big);
            defer std.crypto.secureZero(u8, &shared);
            return truncate(allocator, &shared, bits);
        },
    }
}

fn truncate(allocator: std.mem.Allocator, bytes: []const u8, bits: u32) ![]u8 {
    // §24.4.2 step 11: keep the first length bits, clearing unused low bits.
    const result = try allocator.dupe(u8, bytes[0 .. (bits + 7) / 8]);
    if (bits % 8 != 0) result[result.len - 1] &= @as(u8, 0xff) << @intCast(8 - bits % 8);
    return result;
}

fn p521Public(allocator: std.mem.Allocator, bytes: []const u8, private: bool) ![]u8 {
    if (!mbed.available) return error.NotSupportedError;
    var key = try mbed.Key.importP521(bytes, private, 0, 0);
    defer key.deinit();
    var public: [133]u8 = undefined;
    var written: usize = 0;
    try mbed.check(c.psa_export_public_key(key.id, &public, public.len, &written));
    if (written != public.len) return error.OperationError;
    return allocator.dupe(u8, &public);
}

fn hashMessage(hash: Hash, message: []const u8, buffer: *[64]u8) []const u8 {
    switch (hash) {
        inline else => |algorithm| {
            const H = algorithm.Implementation();
            H.hash(message, buffer[0..H.digest_length], .{});
            return buffer[0..H.digest_length];
        },
    }
}

fn hex(comptime text: []const u8) [text.len / 2]u8 {
    var result: [text.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&result, text) catch unreachable;
    return result;
}

fn checkSignature(curve: Curve, secret: []const u8, public: []const u8, signature: []const u8) !void {
    const a = std.testing.allocator;
    const actual_public = try publicKey(a, curve, secret);
    defer a.free(actual_public);
    try std.testing.expectEqualSlices(u8, public, actual_public);
    try std.testing.expect(try verify(curve, .sha256, public, signature, "sample"));
    try std.testing.expect(!try verify(curve, .sha256, public, signature, "changed"));
    try std.testing.expect(!try verify(curve, .sha256, public, signature[1..], "sample"));
    // Independent known-answer verification above; exercise signing at every
    // registered hash length, including hashes shorter/longer than the scalar.
    inline for (std.meta.tags(Hash)) |hash| {
        const signed = try sign(a, std.testing.io, curve, hash, secret, "native signature");
        defer a.free(signed);
        try std.testing.expect(try verify(curve, hash, public, signed, "native signature"));
    }
}

test "P-256 ECDSA verifies RFC 6979 A.2.5 SHA-256 sample" {
    const secret = hex("c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721");
    const public = hex("0460fed4ba255a9d31c961eb74c6356d68c049b8923b61fa6ce669622e60f29fb67903fe1008b8bc99a41ae9e95628bc64f2f1b20c2d7e9f5177a3c294d4462299");
    const signature = hex("efd48b2aacb6a8fd1140dd9cd45e81d69d2c877b56aaf991c34d0ea84eaf3716f7cb1c942d657c41d436c7a1b6e29f65f3e900dbb9aff4064dc4ab2f843acda8");
    try checkSignature(.p256, &secret, &public, &signature);
}

test "P-384 ECDSA verifies RFC 6979 A.2.6 SHA-256 sample" {
    const secret = hex("6b9d3dad2e1b8c1c05b19875b6659f4de23c3b667bf297ba9aa47740787137d896d5724e4c70a825f872c9ea60d2edf5");
    const public = hex("04ec3a4e415b4e19a4568618029f427fa5da9a8bc4ae92e02e06aae5286b300c64def8f0ea9055866064a254515480bc138015d9b72d7d57244ea8ef9ac0c621896708a59367f9dfb9f54ca84b3f1c9db1288b231c3ae0d4fe7344fd2533264720");
    const signature = hex("21b13d1e013c7fa1392d03c5f99af8b30c570c6f98d4ea8e354b63a21d3daa33bde1e888e63355d92fa2b3c36d8fb2cdf3aa443fb107745bf4bd77cb3891674632068a10ca67e3d45db2266fa7d1feebefdc63eccd1ac42ec0cb8668a4fa0ab0");
    try checkSignature(.p384, &secret, &public, &signature);
}

test "P-521 ECDSA verifies RFC 6979 A.2.7 SHA-256 sample" {
    if (!@import("mbed.zig").available) return error.SkipZigTest;
    const secret = hex("00fad06daa62ba3b25d2fb40133da757205de67f5bb0018fee8c86e1b68c7e75caa896eb32f1f47c70855836a6d16fcc1466f6d8fbec67db89ec0c08b0e996b83538");
    const public = hex("0401894550d0785932e00eaa23b694f213f8c3121f86dc97a04e5a7167db4e5bcd371123d46e45db6b5d5370a7f20fb633155d38ffa16d2bd761dcac474b9a2f5023a400493101c962cd4d2fddf782285e64584139c2f91b47f87ff82354d6630f746a28a0db25741b5b34a828008b22acc23f924faafbd4d33f81ea66956dfeaa2bfdfcf5");
    const signature = hex("01511bb4d675114fe266fc4372b87682baecc01d3cc62cf2303c92b3526012659d16876e25c7c1e57648f23b73564d67f61c6f14d527d54972810421e7d87589e1a7004a171143a83163d6df460aaf61522695f207a58b95c0644d87e52aa1a347916e4f7a72930b1bc06dbe22ce3f58264afd23704cbb63b29b931f7de6c9d949a7ecfc");
    try checkSignature(.p521, &secret, &public, &signature);
}

test "ECDH matches RFC 5903 section 8 on all three curves" {
    const Vector = struct { curve: Curve, secret: []const u8, peer: []const u8, shared: []const u8 };
    const vectors = [_]Vector{
        .{ .curve = .p256, .secret = &hex("c88f01f510d9ac3f70a292daa2316de544e9aab8afe84049c62a9c57862d1433"), .peer = &hex("04d12dfb5289c8d4f81208b70270398c342296970a0bccb74c736fc7554494bf6356fbf3ca366cc23e8157854c13c58d6aac23f046ada30f8353e74f33039872ab"), .shared = &hex("d6840f6b42f6edafd13116e0e12565202fef8e9ece7dce03812464d04b9442de") },
        .{ .curve = .p384, .secret = &hex("099f3c7034d4a2c699884d73a375a67f7624ef7c6b3c0f160647b67414dce655e35b538041e649ee3faef896783ab194"), .peer = &hex("04e558dbef53eecde3d3fccfc1aea08a89a987475d12fd950d83cfa41732bc509d0d1ac43a0336def96fda41d0774a3571dcfbec7aacf3196472169e838430367f66eebe3c6e70c416dd5f0c68759dd1fff83fa40142209dff5eaad96db9e6386c"), .shared = &hex("11187331c279962d93d604243fd592cb9d0a926f422e47187521287e7156c5c4d603135569b9e9d09cf5d4a270f59746") },
        .{ .curve = .p521, .secret = &hex("0037ade9319a89f4dabdb3ef411aaccca5123c61acab57b5393dce47608172a095aa85a30fe1c2952c6771d937ba9777f5957b2639bab072462f68c27a57382d4a52"), .peer = &hex("0400d0b3975ac4b799f5bea16d5e13e9af971d5e9b984c9f39728b5e5739735a219b97c356436adc6e95bb0352f6be64a6c2912d4ef2d0433ced2b6171640012d9460f015c68226383956e3bd066e797b623c27ce0eac2f551a10c2c724d9852077b87220b6536c5c408a1d2aebb8e86d678ae49cb57091f4732296579ab44fcd17f0fc56a"), .shared = &hex("01144c7d79ae6956bc8edb8e7c787c4521cb086fa64407f97894e5e6b2d79b04d1427e73ca4baa240a34786859810c06b3c715a3a8cc3151f2bee417996d19f3ddea") },
    };
    for (vectors) |vector| {
        if (vector.curve == .p521 and !@import("mbed.zig").available) continue;
        const shared = try derive(std.testing.allocator, vector.curve, vector.secret, vector.peer, null);
        defer std.testing.allocator.free(shared);
        try std.testing.expectEqualSlices(u8, vector.shared, shared);
        const prefix = try derive(std.testing.allocator, vector.curve, vector.secret, vector.peer, 9);
        defer std.testing.allocator.free(prefix);
        try std.testing.expectEqualSlices(u8, &.{ vector.shared[0], vector.shared[1] & 0x80 }, prefix);
        try std.testing.expectError(error.OperationError, derive(std.testing.allocator, vector.curve, vector.secret, vector.peer, @intCast(vector.shared.len * 8 + 1)));
    }
}

test "EC key decoding rejects identity, off-curve points and invalid private scalars" {
    const a = std.testing.allocator;
    inline for (.{ Curve.p256, Curve.p384, Curve.p521 }) |curve| {
        if (curve == .p521 and !@import("mbed.zig").available) continue;
        const n = switch (curve) {
            .p256 => 32,
            .p384 => 48,
            .p521 => 66,
        };
        try std.testing.expectError(error.DataError, normalizePublic(a, curve, &.{0}));
        try std.testing.expectError(error.DataError, normalizePublic(a, curve, &([_]u8{4} ++ [_]u8{0} ** (2 * n))));
        try std.testing.expectError(error.DataError, publicKey(a, curve, &([_]u8{0} ** n)));
        try std.testing.expectError(error.DataError, publicKey(a, curve, &([_]u8{0xff} ** n)));
    }
}
