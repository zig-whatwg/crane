//! kit/crypto: WebCrypto's primitives (docs/platform-protocol.md 6.8) over Zig
//! std.crypto and mbedTLS - every platform's default and static fallback.
//!
//! Step 0 of the platform protocol: the digests, HMAC, HKDF and PBKDF2 are
//! here over std.crypto. The rest (AES, EC, Ed25519/X25519, RSA) still live in
//! src/webcrypto/{aes,ec,okp,rsa}.zig, which recipes step 5 moves into this
//! part with their known-answer vectors; until then they answer
//! `error.NotSupported` here (TODO(platform step 5)). Nothing calls these
//! operations yet - WebCrypto still calls src/webcrypto directly.

const std = @import("std");
const platform = @import("platform");

const Bytes = platform.Bytes;
const CryptoError = platform.CryptoError;
const HashAlgorithm = platform.HashAlgorithm;
const sha2 = std.crypto.hash.sha2;

fn Hash(comptime hash: HashAlgorithm) type {
    return switch (hash) {
        .sha1 => std.crypto.hash.Sha1,
        .sha256 => sha2.Sha256,
        .sha384 => sha2.Sha384,
        .sha512 => sha2.Sha512,
    };
}

fn Hmac(comptime hash: HashAlgorithm) type {
    return std.crypto.auth.hmac.Hmac(Hash(hash));
}

pub fn digest(allocator: std.mem.Allocator, hash: HashAlgorithm, message: Bytes) CryptoError![]u8 {
    switch (hash) {
        inline else => |h| {
            const H = Hash(h);
            const out = try allocator.alloc(u8, H.digest_length);
            H.hash(message.slice(), out[0..H.digest_length], .{});
            return out;
        },
    }
}

pub fn hmacSign(allocator: std.mem.Allocator, hash: HashAlgorithm, key: Bytes, message: Bytes) CryptoError![]u8 {
    switch (hash) {
        inline else => |h| {
            const M = Hmac(h);
            const out = try allocator.alloc(u8, M.mac_length);
            M.create(out[0..M.mac_length], message.slice(), key.slice());
            return out;
        },
    }
}

pub fn hmacVerify(hash: HashAlgorithm, key: Bytes, signature: Bytes, message: Bytes) bool {
    switch (hash) {
        inline else => |h| {
            const M = Hmac(h);
            if (signature.len != M.mac_length) return false;
            var mac: [M.mac_length]u8 = undefined;
            M.create(&mac, message.slice(), key.slice());
            return std.crypto.timing_safe.eql([M.mac_length]u8, mac, signature.slice()[0..M.mac_length].*);
        },
    }
}

/// HKDF-Extract then HKDF-Expand (RFC 5869) to `bits` bits, a multiple of 8.
pub fn hkdf(allocator: std.mem.Allocator, hash: HashAlgorithm, key: Bytes, salt: Bytes, info: Bytes, bits: u32) CryptoError![]u8 {
    if (bits % 8 != 0) return error.OperationFailed;
    switch (hash) {
        inline else => |h| {
            const K = std.crypto.kdf.hkdf.Hkdf(Hmac(h));
            const length = bits / 8;
            if (length > 255 * Hmac(h).mac_length) return error.OperationFailed;
            const out = try allocator.alloc(u8, length);
            const prk = K.extract(salt.slice(), key.slice());
            K.expand(out, info.slice(), prk);
            return out;
        },
    }
}

/// PBKDF2 (RFC 8018) to `bits` bits, a multiple of 8.
pub fn pbkdf2(allocator: std.mem.Allocator, hash: HashAlgorithm, password: Bytes, salt: Bytes, iterations: u32, bits: u32) CryptoError![]u8 {
    if (bits % 8 != 0 or iterations == 0) return error.OperationFailed;
    switch (hash) {
        inline else => |h| {
            const out = try allocator.alloc(u8, bits / 8);
            errdefer allocator.free(out);
            std.crypto.pwhash.pbkdf2(out, password.slice(), salt.slice(), iterations, Hmac(h)) catch return error.OperationFailed;
            return out;
        },
    }
}

// TODO(platform step 5): the rest move from src/webcrypto with their vectors.

pub fn aesEncrypt(allocator: std.mem.Allocator, mode: *const platform.AesMode, key: Bytes, input: Bytes) CryptoError![]u8 {
    _ = .{ allocator, mode, key, input };
    return error.NotSupported;
}

pub fn aesDecrypt(allocator: std.mem.Allocator, mode: *const platform.AesMode, key: Bytes, input: Bytes) CryptoError![]u8 {
    _ = .{ allocator, mode, key, input };
    return error.NotSupported;
}

pub fn ecGenerate(allocator: std.mem.Allocator, curve: platform.EcCurve) CryptoError![]u8 {
    _ = .{ allocator, curve };
    return error.NotSupported;
}

pub fn ecPublicKey(allocator: std.mem.Allocator, curve: platform.EcCurve, private: Bytes) CryptoError![]u8 {
    _ = .{ allocator, curve, private };
    return error.NotSupported;
}

pub fn ecValidatePublic(allocator: std.mem.Allocator, curve: platform.EcCurve, point: Bytes) CryptoError![]u8 {
    _ = .{ allocator, curve, point };
    return error.NotSupported;
}

pub fn ecdsaSign(allocator: std.mem.Allocator, curve: platform.EcCurve, hash: HashAlgorithm, private: Bytes, message: Bytes) CryptoError![]u8 {
    _ = .{ allocator, curve, hash, private, message };
    return error.NotSupported;
}

pub fn ecdsaVerify(curve: platform.EcCurve, hash: HashAlgorithm, public: Bytes, signature: Bytes, message: Bytes) CryptoError!bool {
    _ = .{ curve, hash, public, signature, message };
    return error.NotSupported;
}

pub fn ecdhDerive(allocator: std.mem.Allocator, curve: platform.EcCurve, private: Bytes, peer_public: Bytes, bits: ?u32) CryptoError![]u8 {
    _ = .{ allocator, curve, private, peer_public, bits };
    return error.NotSupported;
}

pub fn okpPublicKey(allocator: std.mem.Allocator, curve: platform.OkpCurve, private: Bytes) CryptoError![]u8 {
    _ = .{ allocator, curve, private };
    return error.NotSupported;
}

pub fn ed25519Sign(allocator: std.mem.Allocator, private: Bytes, message: Bytes) CryptoError![]u8 {
    _ = .{ allocator, private, message };
    return error.NotSupported;
}

pub fn ed25519Verify(public: Bytes, signature: Bytes, message: Bytes) CryptoError!bool {
    _ = .{ public, signature, message };
    return error.NotSupported;
}

pub fn x25519Derive(allocator: std.mem.Allocator, private: Bytes, peer_public: Bytes) CryptoError![]u8 {
    _ = .{ allocator, private, peer_public };
    return error.NotSupported;
}

pub fn rsaGenerate(allocator: std.mem.Allocator, bits: u32, exponent: Bytes) CryptoError![]u8 {
    _ = .{ allocator, bits, exponent };
    return error.NotSupported;
}

pub fn rsaPublicKey(allocator: std.mem.Allocator, private_der: Bytes) CryptoError![]u8 {
    _ = .{ allocator, private_der };
    return error.NotSupported;
}

pub fn rsaSign(allocator: std.mem.Allocator, padding: platform.RsaPadding, hash: HashAlgorithm, private_der: Bytes, message: Bytes) CryptoError![]u8 {
    _ = .{ allocator, padding, hash, private_der, message };
    return error.NotSupported;
}

pub fn rsaVerify(padding: platform.RsaPadding, hash: HashAlgorithm, public_der: Bytes, signature: Bytes, message: Bytes) CryptoError!bool {
    _ = .{ padding, hash, public_der, signature, message };
    return error.NotSupported;
}

pub fn rsaEncrypt(allocator: std.mem.Allocator, hash: HashAlgorithm, label: Bytes, key_der: Bytes, input: Bytes) CryptoError![]u8 {
    _ = .{ allocator, hash, label, key_der, input };
    return error.NotSupported;
}

pub fn rsaDecrypt(allocator: std.mem.Allocator, hash: HashAlgorithm, label: Bytes, key_der: Bytes, input: Bytes) CryptoError![]u8 {
    _ = .{ allocator, hash, label, key_der, input };
    return error.NotSupported;
}
