//! WebCrypto §§20–22 using the already-linked mbedTLS 3.6.4 artifact.

const std = @import("std");
const keys = @import("key.zig");
const Hash = @import("hash.zig").Hash;
const Direction = @import("aes.zig").Direction;
const mbed = @import("mbed.zig");
const c = mbed.c;
const der = @import("der.zig");
const Context = if (mbed.available) c.mbedtls_pk_context else void;

pub fn generateSecret(allocator: std.mem.Allocator, bits: u32, exponent: []const u8) ![]u8 {
    try validateGeneration(bits, exponent);
    if (!mbed.available) return error.NotSupportedError;
    // §§20.9.3/21.4.3/22.4.3 steps 2–4: generate the requested RSA key,
    // export it immediately, then destroy the transient PSA key ID.
    try mbed.check(c.psa_crypto_init());
    var attributes = c.psa_key_attributes_init();
    defer c.psa_reset_key_attributes(&attributes);
    c.psa_set_key_type(&attributes, c.PSA_KEY_TYPE_RSA_KEY_PAIR);
    c.psa_set_key_bits(&attributes, bits);
    c.psa_set_key_usage_flags(&attributes, c.PSA_KEY_USAGE_EXPORT);
    const custom: c.psa_custom_key_parameters_t = .{ .flags = 0 };
    const normalized = std.mem.trimStart(u8, exponent, &.{0});
    var key: mbed.Key = undefined;
    try mbed.check(c.psa_generate_key_custom(&attributes, &custom, normalized.ptr, normalized.len, &key.id));
    defer key.deinit();
    const buffer = try allocator.alloc(u8, c.PSA_EXPORT_KEY_OUTPUT_SIZE(c.PSA_KEY_TYPE_RSA_KEY_PAIR, bits));
    defer erase(allocator, buffer);
    var written: usize = 0;
    try mbed.check(c.psa_export_key(key.id, buffer.ptr, buffer.len, &written));
    return allocator.dupe(u8, buffer[0..written]);
}

pub fn publicKey(allocator: std.mem.Allocator, private: []const u8) ![]u8 {
    const parts = try components(private, true);
    return encodeComponents(allocator, .{ .n = parts.n, .e = parts.e });
}

pub fn sign(allocator: std.mem.Allocator, io: std.Io, key: *const keys.Slots, message: []const u8, salt: ?u32) ![]u8 {
    // §§20.9.1/21.4.1 step 1: private key before the cryptographic operation.
    if (key.kind != .private) return error.InvalidAccessError;
    if (!mbed.available) return error.NotSupportedError;
    const hash = key.algorithm.hash orelse return error.OperationError;
    const size = try modulusBytes(key);
    var digest: [64]u8 = undefined;
    defer std.crypto.secureZero(u8, &digest);
    const hashed = hashMessage(hash, message, &digest);
    const result = try allocator.alloc(u8, size);
    errdefer erase(allocator, result);
    if (key.algorithm.id == .rsa_pss) {
        // §21.4.1 step 2: key hash for both H and MGF1; saltLength is exact.
        const salt_length = salt orelse return error.TypeError;
        if (!validSalt(key.algorithm.modulus_length.?, hash, salt_length)) return error.OperationError;
        var context: Context = undefined;
        c.mbedtls_pk_init(&context);
        defer freeContext(&context);
        try loadContext(&context, key.material, true);
        const rsa = c.mbedtls_pk_rsa(context);
        try mbed.check(c.mbedtls_rsa_set_padding(rsa, c.MBEDTLS_RSA_PKCS_V21, digestId(hash)));
        var entropy = io;
        try mbed.check(c.mbedtls_rsa_rsassa_pss_sign_ext(rsa, random, &entropy, digestId(hash), @intCast(hashed.len), hashed.ptr, @intCast(salt_length), result.ptr));
    } else if (key.algorithm.id == .rsa_pkcs1) {
        // §20.9.1 steps 2–4: RSASSA-PKCS1-v1_5 with the key's hash.
        const algorithm = c.PSA_ALG_RSA_PKCS1V15_SIGN(mbed.hashAlgorithm(hash));
        var native = try importPsa(key, algorithm, c.PSA_KEY_USAGE_SIGN_HASH);
        defer native.deinit();
        var written: usize = 0;
        try mbed.check(c.psa_sign_hash(native.id, algorithm, hashed.ptr, hashed.len, result.ptr, result.len, &written));
        if (written != result.len) return error.OperationError;
    } else return error.NotSupportedError;
    return result;
}

pub fn verify(key: *const keys.Slots, signature: []const u8, message: []const u8, salt: ?u32) !bool {
    // §§20.9.2/21.4.2 step 1.
    if (key.kind != .public) return error.InvalidAccessError;
    if (!mbed.available) return error.NotSupportedError;
    if (signature.len != try modulusBytes(key)) return false;
    const hash = key.algorithm.hash orelse return error.OperationError;
    var digest: [64]u8 = undefined;
    defer std.crypto.secureZero(u8, &digest);
    const hashed = hashMessage(hash, message, &digest);
    if (key.algorithm.id == .rsa_pss) {
        const salt_length = salt orelse return error.TypeError;
        if (!validSalt(key.algorithm.modulus_length.?, hash, salt_length)) return false;
        var context: Context = undefined;
        c.mbedtls_pk_init(&context);
        defer freeContext(&context);
        try loadContext(&context, key.material, false);
        // §21.4.2 steps 2–4: never pass MBEDTLS_RSA_SALT_LEN_ANY.
        return c.mbedtls_rsa_rsassa_pss_verify_ext(c.mbedtls_pk_rsa(context), digestId(hash), @intCast(hashed.len), hashed.ptr, digestId(hash), @intCast(salt_length), signature.ptr) == 0;
    }
    if (key.algorithm.id != .rsa_pkcs1) return error.NotSupportedError;
    const algorithm = c.PSA_ALG_RSA_PKCS1V15_SIGN(mbed.hashAlgorithm(hash));
    var native = try importPsa(key, algorithm, c.PSA_KEY_USAGE_VERIFY_HASH);
    defer native.deinit();
    // §20.9.2 steps 2–4: invalid signatures return false.
    const status = c.psa_verify_hash(native.id, algorithm, hashed.ptr, hashed.len, signature.ptr, signature.len);
    if (status == c.PSA_ERROR_INVALID_SIGNATURE) return false;
    try mbed.check(status);
    return true;
}

pub fn crypt(allocator: std.mem.Allocator, direction: Direction, key: *const keys.Slots, bytes: []const u8, label: []const u8) ![]u8 {
    // §22.4.1/2 step 1: encrypt with public, decrypt with private.
    if (key.kind != (if (direction == .encrypt) keys.Kind.public else .private)) return error.InvalidAccessError;
    if (!mbed.available) return error.NotSupportedError;
    const hash = key.algorithm.hash orelse return error.OperationError;
    const size = try modulusBytes(key);
    const overhead = 2 * hash.digestLength() + 2;
    // RFC 3447 §7.1 bounds, including moduli too short for this hash.
    if (size < overhead or (direction == .encrypt and bytes.len > size - overhead) or (direction == .decrypt and bytes.len != size)) return error.OperationError;
    const algorithm = c.PSA_ALG_RSA_OAEP(mbed.hashAlgorithm(hash));
    var native = try importPsa(key, algorithm, if (direction == .encrypt) c.PSA_KEY_USAGE_ENCRYPT else c.PSA_KEY_USAGE_DECRYPT);
    defer native.deinit();
    const buffer = try allocator.alloc(u8, size);
    defer erase(allocator, buffer);
    var written: usize = 0;
    // §22.4.1/2 steps 2–5: explicit label, MGF1 with the key's hash.
    const status = if (direction == .encrypt)
        c.psa_asymmetric_encrypt(native.id, algorithm, bytes.ptr, bytes.len, label.ptr, label.len, buffer.ptr, buffer.len, &written)
    else
        c.psa_asymmetric_decrypt(native.id, algorithm, bytes.ptr, bytes.len, label.ptr, label.len, buffer.ptr, buffer.len, &written);
    try mbed.check(status);
    return allocator.dupe(u8, buffer[0..written]);
}

fn modulusBytes(key: *const keys.Slots) !usize {
    return (@as(usize, key.algorithm.modulus_length orelse return error.OperationError) + 7) / 8;
}

fn validSalt(bits: u32, hash: Hash, salt: u32) bool {
    if (bits == 0) return false;
    const encoded_length = (@as(u64, bits) + 6) / 8; // ceil((modBits - 1)/8).
    return @as(u64, salt) + hash.digestLength() + 2 <= encoded_length and salt <= std.math.maxInt(c_int);
}

fn importPsa(key: *const keys.Slots, algorithm: u32, usage: u32) !mbed.Key {
    if (!mbed.available) return error.NotSupportedError;
    try mbed.check(c.psa_crypto_init());
    var attributes = c.psa_key_attributes_init();
    defer c.psa_reset_key_attributes(&attributes);
    c.psa_set_key_type(&attributes, if (key.kind == .private) c.PSA_KEY_TYPE_RSA_KEY_PAIR else c.PSA_KEY_TYPE_RSA_PUBLIC_KEY);
    c.psa_set_key_algorithm(&attributes, algorithm);
    c.psa_set_key_usage_flags(&attributes, usage);
    var result: mbed.Key = undefined;
    try mbed.check(c.psa_import_key(&attributes, key.material.ptr, key.material.len, &result.id));
    return result;
}

fn digestId(hash: Hash) u32 {
    if (!mbed.available) return 0;
    return switch (hash) {
        .sha1 => c.MBEDTLS_MD_SHA1,
        .sha256 => c.MBEDTLS_MD_SHA256,
        .sha384 => c.MBEDTLS_MD_SHA384,
        .sha512 => c.MBEDTLS_MD_SHA512,
    };
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

fn random(context: ?*anyopaque, output: [*c]u8, length: usize) callconv(.c) c_int {
    const io: *const std.Io = @ptrCast(@alignCast(context.?));
    io.randomSecure(output[0..length]) catch return -1;
    return 0;
}

fn psaRandom(_: ?*anyopaque, output: [*c]u8, length: usize) callconv(.c) c_int {
    if (!mbed.available) return -1;
    return if (c.psa_generate_random(output, length) == c.PSA_SUCCESS) 0 else -1;
}

fn loadContext(context: *Context, bytes: []const u8, private: bool) !void {
    if (!mbed.available) return error.NotSupportedError;
    try mbed.check(c.psa_crypto_init());
    // Parse only previously DER-validated PKCS#1; pass an explicit CSPRNG for
    // the private parser's blinding contract, including import validation.
    const status = if (private) c.mbedtls_pk_parse_key(context, bytes.ptr, bytes.len, null, 0, psaRandom, null) else c.mbedtls_pk_parse_public_key(context, bytes.ptr, bytes.len);
    if (status != 0 or c.mbedtls_pk_rsa(context.*) == null) return error.DataError;
    const rsa = c.mbedtls_pk_rsa(context.*);
    if ((if (private) c.mbedtls_rsa_check_privkey(rsa) else c.mbedtls_rsa_check_pubkey(rsa)) != 0) return error.DataError;
}

fn freeContext(context: *Context) void {
    if (!mbed.available) return;
    c.mbedtls_pk_free(context);
    std.crypto.secureZero(u8, std.mem.asBytes(context));
}

fn erase(allocator: std.mem.Allocator, bytes: []u8) void {
    std.crypto.secureZero(u8, bytes);
    allocator.free(bytes);
}

pub fn validateGeneration(bits: u32, exponent: []const u8) !void {
    // §20.5 steps 1–3: exponent is an unsigned big-endian integer; require
    // modulusLength >= 4 and odd 3 <= exponent < 2^modulusLength - 1.
    const bytes = std.mem.trimStart(u8, exponent, &.{0});
    if (bits < 4 or bytes.len == 0 or bytes[bytes.len - 1] & 1 == 0 or (bytes.len == 1 and bytes[0] < 3)) return error.OperationError;
    const exponent_bits = try bitLength(bytes);
    if (exponent_bits > bits) return error.OperationError;
    if (exponent_bits == bits) {
        const first: u8 = @as(u8, 0xff) >> @intCast(@clz(bytes[0]));
        if (bytes[0] == first) {
            for (bytes[1..]) |byte| if (byte != 0xff) return;
            return error.OperationError;
        }
    }
}

pub fn bitLength(bytes: []const u8) !u32 {
    const significant = std.mem.trimStart(u8, bytes, &.{0});
    if (significant.len == 0) return 0;
    if (significant.len > std.math.maxInt(u32) / 8) return error.OperationError;
    return @as(u32, @intCast(significant.len * 8)) - @clz(significant[0]);
}

/// Borrowed PKCS#1 components. A private key has d; CRT values are all-or-none.
pub const Components = struct {
    n: []const u8,
    e: []const u8,
    d: ?[]const u8 = null,
    p: ?[]const u8 = null,
    q: ?[]const u8 = null,
    dp: ?[]const u8 = null,
    dq: ?[]const u8 = null,
    qi: ?[]const u8 = null,
};

pub fn components(bytes: []const u8, private: bool) !Components {
    // RFC 3447 A.1.1–2 and WebCrypto §9: exact, canonical positive integers.
    var reader = try der.sequence(bytes);
    if (private and !std.mem.eql(u8, try reader.integer(), &.{0})) return error.DataError;
    var result: Components = .{ .n = try positiveInteger(&reader), .e = try positiveInteger(&reader) };
    if (private) inline for (.{ "d", "p", "q", "dp", "dq", "qi" }) |field| {
        @field(result, field) = try positiveInteger(&reader);
    };
    try reader.finish();
    return result;
}

fn positiveInteger(reader: *der.Reader) ![]const u8 {
    const value = try reader.integer();
    if (value.len == 1 and value[0] == 0) return error.DataError;
    return value;
}

pub fn importDer(allocator: std.mem.Allocator, bytes: []const u8, private: bool) ![]u8 {
    if (!mbed.available) return error.NotSupportedError;
    _ = try components(bytes, private);
    var context: Context = undefined;
    c.mbedtls_pk_init(&context);
    defer freeContext(&context);
    // Import Key's validity step includes all private-key relationships,
    // especially CRT values: the library's parser alone does not check them.
    try loadContext(&context, bytes, private);
    return allocator.dupe(u8, bytes);
}

pub fn importComponents(allocator: std.mem.Allocator, parts: Components) ![]u8 {
    if (!mbed.available) return error.NotSupportedError;
    if (parts.d == null or parts.p != null) {
        const encoded = try encodeComponents(allocator, parts);
        defer erase(allocator, encoded);
        return importDer(allocator, encoded, parts.d != null);
    }
    // RFC 7518 §6.3.2 permits n/e/d without any CRT optimization parameters.
    if (parts.q != null or parts.dp != null or parts.dq != null or parts.qi != null) return error.DataError;
    try mbed.check(c.psa_crypto_init());
    var context: Context = undefined;
    c.mbedtls_pk_init(&context);
    defer freeContext(&context);
    try mbed.check(c.mbedtls_pk_setup(&context, c.mbedtls_pk_info_from_type(c.MBEDTLS_PK_RSA)));
    const rsa = c.mbedtls_pk_rsa(context);
    const secret = parts.d.?;
    if (c.mbedtls_rsa_import_raw(rsa, parts.n.ptr, parts.n.len, null, 0, null, 0, secret.ptr, secret.len, parts.e.ptr, parts.e.len) != 0 or
        c.mbedtls_rsa_complete(rsa) != 0 or c.mbedtls_rsa_check_privkey(rsa) != 0) return error.DataError;
    // Export the completed key to Crane-owned bytes. Context and intermediates
    // are freed in this call; no mutex-bearing C context is copied or retained.
    var buffer: [c.MBEDTLS_MPI_MAX_SIZE * 9 + 128]u8 = undefined;
    defer std.crypto.secureZero(u8, &buffer);
    const written = c.mbedtls_pk_write_key_der(&context, &buffer, buffer.len);
    if (written < 0) return error.DataError;
    return allocator.dupe(u8, buffer[buffer.len - @as(usize, @intCast(written)) ..]);
}

fn encodeComponents(allocator: std.mem.Allocator, parts: Components) ![]u8 {
    var encoded: [8]?[]u8 = @splat(null);
    defer for (encoded) |part| if (part) |bytes| erase(allocator, bytes);
    encoded[0] = try der.encodeInteger(allocator, parts.n);
    encoded[1] = try der.encodeInteger(allocator, parts.e);
    if (parts.d == null) return der.encode(allocator, 0x30, &.{ encoded[0].?, encoded[1].? });
    inline for (.{ "d", "p", "q", "dp", "dq", "qi" }, 2..) |field, index| {
        encoded[index] = try der.encodeInteger(allocator, @field(parts, field) orelse return error.DataError);
    }
    return der.encode(allocator, 0x30, &.{ "\x02\x01\x00", encoded[0].?, encoded[1].?, encoded[2].?, encoded[3].?, encoded[4].?, encoded[5].?, encoded[6].?, encoded[7].? });
}

test "RSA PKCS1-v1_5 matches independent WPT SHA-256 signature" {
    if (!@import("mbed.zig").available) return error.SkipZigTest;
    const a = std.testing.allocator;
    const vectors = @import("rsa_vectors.zig");
    const formats = @import("asymmetric_keys.zig");
    const algorithm: keys.Algorithm = .{ .id = .rsa_pkcs1, .hash = .sha256 };
    var private = try formats.importKey(a, .pkcs8, algorithm, &vectors.key_pkcs8, null, true, keys.Usages.initOne(.sign));
    defer private.deinit();
    var public = try formats.importKey(a, .spki, algorithm, &vectors.key_spki, null, true, keys.Usages.initOne(.verify));
    defer public.deinit();
    try std.testing.expectEqual(@as(?u32, 2048), public.algorithm.modulus_length);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 1 }, public.algorithm.public_exponent.?);
    const result = try sign(a, std.testing.io, &private, &vectors.pkcs_plaintext, null);
    defer a.free(result);
    try std.testing.expectEqualSlices(u8, &vectors.pkcs_sha256, result);
    try std.testing.expect(try verify(&public, &vectors.pkcs_sha256, &vectors.pkcs_plaintext, null));
    try std.testing.expect(!try verify(&public, &vectors.pkcs_sha256, "changed", null));
    try std.testing.expectError(error.InvalidAccessError, sign(a, std.testing.io, &public, "", null));
    try std.testing.expectError(error.InvalidAccessError, verify(&private, result, "", null));
}

test "RSA-PSS enforces exact salt length including zero and maximum" {
    if (!@import("mbed.zig").available) return error.SkipZigTest;
    const a = std.testing.allocator;
    const vectors = @import("rsa_vectors.zig");
    const formats = @import("asymmetric_keys.zig");
    const algorithm: keys.Algorithm = .{ .id = .rsa_pss, .hash = .sha256 };
    var private = try formats.importKey(a, .pkcs8, algorithm, &vectors.key_pkcs8, null, true, keys.Usages.initOne(.sign));
    defer private.deinit();
    var public = try formats.importKey(a, .spki, algorithm, &vectors.key_spki, null, true, keys.Usages.initOne(.verify));
    defer public.deinit();
    try std.testing.expect(try verify(&public, &vectors.pss_sha256_no_salt, &vectors.pss_plaintext, 0));
    try std.testing.expect(try verify(&public, &vectors.pss_sha256_salted, &vectors.pss_plaintext, 32));
    try std.testing.expect(!try verify(&public, &vectors.pss_sha256_salted, &vectors.pss_plaintext, 31));
    const no_salt = try sign(a, std.testing.io, &private, &vectors.pss_plaintext, 0);
    defer a.free(no_salt);
    try std.testing.expectEqualSlices(u8, &vectors.pss_sha256_no_salt, no_salt);
    for ([_]u32{ 1, 20, 32, 222 }) |salt_length| {
        const signature = try sign(a, std.testing.io, &private, &vectors.pss_plaintext, salt_length);
        defer a.free(signature);
        try std.testing.expect(try verify(&public, signature, &vectors.pss_plaintext, salt_length));
        try std.testing.expect(!try verify(&public, signature, &vectors.pss_plaintext, salt_length - 1));
    }
    try std.testing.expectError(error.OperationError, sign(a, std.testing.io, &private, "", 223));
    try std.testing.expect(!try verify(&public, &vectors.pss_sha256_salted, &vectors.pss_plaintext, std.math.maxInt(u32)));
}

test "RSA-OAEP decrypts independent WPT vectors and binds its label" {
    if (!@import("mbed.zig").available) return error.SkipZigTest;
    const a = std.testing.allocator;
    const vectors = @import("rsa_vectors.zig");
    const formats = @import("asymmetric_keys.zig");
    const algorithm: keys.Algorithm = .{ .id = .rsa_oaep, .hash = .sha256 };
    var private = try formats.importKey(a, .pkcs8, algorithm, &vectors.key_pkcs8, null, true, keys.Usages.initOne(.decrypt));
    defer private.deinit();
    var public = try formats.importKey(a, .spki, algorithm, &vectors.key_spki, null, true, keys.Usages.initOne(.encrypt));
    defer public.deinit();
    const plaintext = try crypt(a, .decrypt, &private, &vectors.oaep_sha256_no_label, "");
    defer a.free(plaintext);
    try std.testing.expectEqualSlices(u8, vectors.oaep_plaintext[0..190], plaintext);
    const labeled = try crypt(a, .decrypt, &private, &vectors.oaep_sha256_with_label, &vectors.oaep_label);
    defer a.free(labeled);
    try std.testing.expectEqualSlices(u8, vectors.oaep_plaintext[0..190], labeled);
    try std.testing.expectError(error.OperationError, crypt(a, .decrypt, &private, &vectors.oaep_sha256_with_label, "wrong label"));
    const encrypted = try crypt(a, .encrypt, &public, "new plaintext", &vectors.oaep_label);
    defer a.free(encrypted);
    const decrypted = try crypt(a, .decrypt, &private, encrypted, &vectors.oaep_label);
    defer a.free(decrypted);
    try std.testing.expectEqualStrings("new plaintext", decrypted);
    try std.testing.expectError(error.OperationError, crypt(a, .encrypt, &public, vectors.oaep_plaintext[0..191], ""));
    try std.testing.expectError(error.InvalidAccessError, crypt(a, .encrypt, &private, "", ""));
}

test "RSA generation validates the exact WebCrypto integer bounds" {
    try validateGeneration(4, &.{3});
    try validateGeneration(16, &.{ 0, 0, 3 });
    try validateGeneration(2048, &.{ 1, 0, 1 });
    try std.testing.expectError(error.OperationError, validateGeneration(3, &.{3}));
    try std.testing.expectError(error.OperationError, validateGeneration(4, &.{15}));
    try std.testing.expectError(error.OperationError, validateGeneration(4, &.{17}));
    for ([_][]const u8{ "", &.{0}, &.{1}, &.{2}, &.{4} }) |exponent| {
        try std.testing.expectError(error.OperationError, validateGeneration(2048, exponent));
    }
}

test "RSA generation supports a custom public exponent and every key format" {
    if (!@import("mbed.zig").available) return error.SkipZigTest;
    const a = std.testing.allocator;
    const formats = @import("asymmetric_keys.zig");
    var pair = try formats.generate(a, std.testing.io, .{ .id = .rsa_pss, .hash = .sha256, .modulus_length = 1024, .public_exponent = &.{3} }, true, keys.Usages.initMany(&.{ .sign, .verify }));
    defer pair.public_key.deinit();
    defer pair.private_key.deinit();
    try std.testing.expectEqual(@as(?u32, 1024), pair.public_key.algorithm.modulus_length);
    try std.testing.expectEqualSlices(u8, &.{3}, pair.public_key.algorithm.public_exponent.?);
    inline for (.{ keys.Format.pkcs8, keys.Format.jwk }) |format| {
        const encoded = try formats.exportKey(a, &pair.private_key, format);
        defer a.free(encoded);
        const parsed = if (format == .jwk) try std.json.parseFromSlice(@import("jwk.zig").Data, a, encoded, .{}) else {};
        defer if (format == .jwk) parsed.deinit();
        var imported = try formats.importKey(a, format, .{ .id = .rsa_pss, .hash = .sha256 }, encoded, if (format == .jwk) parsed.value else null, true, keys.Usages.initOne(.sign));
        defer imported.deinit();
        const signed = try sign(a, std.testing.io, &imported, "custom exponent", 7);
        defer a.free(signed);
        try std.testing.expect(try verify(&pair.public_key, signed, "custom exponent", 7));
    }
}

test "RSA private import rejects inconsistent CRT values and recovers optional JWK factors" {
    if (!@import("mbed.zig").available) return error.SkipZigTest;
    const a = std.testing.allocator;
    const formats = @import("asymmetric_keys.zig");
    const vectors = @import("rsa_vectors.zig");
    const algorithm: keys.Algorithm = .{ .id = .rsa_pkcs1, .hash = .sha256 };
    const usages = keys.Usages.initOne(.sign);
    var corrupt = vectors.key_pkcs8;
    corrupt[corrupt.len - 1] ^= 1;
    try std.testing.expectError(error.DataError, formats.importKey(a, .pkcs8, algorithm, &corrupt, null, true, usages));
    var original = try formats.importKey(a, .pkcs8, algorithm, &vectors.key_pkcs8, null, true, usages);
    defer original.deinit();
    const encoded = try formats.exportKey(a, &original, .jwk);
    defer a.free(encoded);
    const parsed = try std.json.parseFromSlice(@import("jwk.zig").Data, a, encoded, .{});
    defer parsed.deinit();
    var dictionary = parsed.value;
    dictionary.p = null;
    try std.testing.expectError(error.DataError, formats.importKey(a, .jwk, algorithm, "", dictionary, true, usages));
    dictionary.q = null;
    dictionary.dp = null;
    dictionary.dq = null;
    dictionary.qi = null;
    var recovered = try formats.importKey(a, .jwk, algorithm, "", dictionary, true, usages);
    defer recovered.deinit();
    const signature = try sign(a, std.testing.io, &recovered, &vectors.pkcs_plaintext, null);
    defer a.free(signature);
    try std.testing.expectEqualSlices(u8, &vectors.pkcs_sha256, signature);
}

fn checkFormatAllocations(allocator: std.mem.Allocator) anyerror!void {
    const formats = @import("asymmetric_keys.zig");
    const vectors = @import("rsa_vectors.zig");
    const algorithm: keys.Algorithm = .{ .id = .rsa_oaep, .hash = .sha256 };
    var original = try formats.importKey(allocator, .pkcs8, algorithm, &vectors.key_pkcs8, null, true, keys.Usages.initOne(.decrypt));
    defer original.deinit();
    const json = try formats.exportKey(allocator, &original, .jwk);
    defer erase(allocator, json);
    const parsed = try std.json.parseFromSlice(@import("jwk.zig").Data, allocator, json, .{});
    defer parsed.deinit();
    var copy = try formats.importKey(allocator, .jwk, algorithm, "", parsed.value, true, keys.Usages.initOne(.decrypt));
    defer copy.deinit();
    const pkcs8 = try formats.exportKey(allocator, &copy, .pkcs8);
    defer erase(allocator, pkcs8);
    try std.testing.expectEqualSlices(u8, &vectors.key_pkcs8, pkcs8);
}

test "RSA formats release all key and metadata allocations on every failure" {
    if (!mbed.available) return error.SkipZigTest;
    try std.testing.checkAllAllocationFailures(std.testing.allocator, checkFormatAllocations, .{});
}

test "RSA JWK rejects nonminimal integers and inconsistent metadata" {
    if (!mbed.available) return error.SkipZigTest;
    const a = std.testing.allocator;
    const formats = @import("asymmetric_keys.zig");
    const algorithm: keys.Algorithm = .{ .id = .rsa_pss, .hash = .sha256 };
    var key = try formats.importKey(a, .spki, algorithm, &@import("rsa_vectors.zig").key_spki, null, true, keys.Usages.initOne(.verify));
    defer key.deinit();
    const json = try formats.exportKey(a, &key, .jwk);
    defer a.free(json);
    const parsed = try std.json.parseFromSlice(@import("jwk.zig").Data, a, json, .{});
    defer parsed.deinit();
    const uses = keys.Usages.initOne(.verify);
    var invalid = parsed.value;
    invalid.e = "AAEAAQ"; // 00 01 00 01: forbidden leading zero.
    try std.testing.expectError(error.DataError, formats.importKey(a, .jwk, algorithm, "", invalid, true, uses));
    invalid = parsed.value;
    invalid.alg = "RS256";
    try std.testing.expectError(error.DataError, formats.importKey(a, .jwk, algorithm, "", invalid, true, uses));
    invalid = parsed.value;
    invalid.ext = false;
    try std.testing.expectError(error.DataError, formats.importKey(a, .jwk, algorithm, "", invalid, true, uses));
    invalid = parsed.value;
    invalid.use = "enc";
    try std.testing.expectError(error.DataError, formats.importKey(a, .jwk, algorithm, "", invalid, true, uses));
    // The format's usage check still precedes its malformed key-data check.
    try std.testing.expectError(error.SyntaxError, formats.importKey(a, .jwk, algorithm, "", invalid, true, keys.Usages.initOne(.encrypt)));
}
