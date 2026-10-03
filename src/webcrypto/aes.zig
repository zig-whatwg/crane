//! WebCrypto §27-30: AES modes and key wrapping.

const std = @import("std");
const mbed = @import("mbed.zig");
const c = mbed.c;
const core = std.crypto.core.aes;

pub const Direction = enum { encrypt, decrypt };

/// CTR increments only the rightmost `counter_bits`, including across wraparound.
pub fn ctr(allocator: std.mem.Allocator, key: []const u8, counter: []const u8, counter_bits: u8, input: []const u8) ![]u8 {
    // §27.7.1/2 steps 1-2: the block and counter width are checked first.
    if (counter.len != 16 or counter_bits == 0 or counter_bits > 128) return error.OperationError;
    // SP 800-38A B.1: counter blocks must be distinct within this message.
    const blocks = input.len / 16 + @intFromBool(input.len % 16 != 0);
    if (counter_bits < @bitSizeOf(usize) and blocks > (@as(usize, 1) << @intCast(counter_bits))) return error.OperationError;
    var cipher = try BlockCipher.init(key, .encrypt);
    defer cipher.deinit();
    const result = try allocator.alloc(u8, input.len);
    errdefer eraseFree(allocator, result);
    // Steps 3-4: encrypt counters and xor, incrementing only the low m bits.
    const initial = std.mem.readInt(u128, counter[0..16], .big);
    const mask: u128 = if (counter_bits == 128) std.math.maxInt(u128) else (@as(u128, 1) << @intCast(counter_bits)) - 1;
    var current = initial;
    var offset: usize = 0;
    while (offset < input.len) : (offset += @min(16, input.len - offset)) {
        var block: [16]u8 = undefined;
        std.mem.writeInt(u128, &block, current, .big);
        var stream: [16]u8 = undefined;
        defer std.crypto.secureZero(u8, &stream);
        try cipher.apply(&stream, &block);
        const count = @min(16, input.len - offset);
        for (0..count) |i| result[offset + i] = input[offset + i] ^ stream[i];
        current = (initial & ~mask) | ((current +% 1) & mask);
    }
    return result;
}

/// CBC uses mandatory PKCS#7 padding, including a whole block for aligned input.
pub fn cbc(allocator: std.mem.Allocator, direction: Direction, key: []const u8, iv: []const u8, input: []const u8) ![]u8 {
    // §28.4.1 step 1 / §28.4.2 steps 1-2.
    if (iv.len != 16) return error.OperationError;
    if (direction == .decrypt and (input.len == 0 or input.len % 16 != 0)) return error.OperationError;
    const output_length = if (direction == .encrypt)
        std.math.add(usize, input.len, 16 - input.len % 16) catch return error.OperationError
    else
        input.len;
    var cipher = try BlockCipher.init(key, direction);
    defer cipher.deinit();
    var result = try allocator.alloc(u8, output_length);
    errdefer eraseFree(allocator, result);
    var previous = iv[0..16].*;
    defer std.crypto.secureZero(u8, &previous);
    var offset: usize = 0;
    while (offset < output_length) : (offset += 16) {
        var block: [16]u8 = undefined;
        defer std.crypto.secureZero(u8, &block);
        if (direction == .encrypt) {
            // §28.4.1 steps 2-3: PKCS#7, followed by CBC encryption.
            for (0..16) |i| {
                const byte = if (offset + i < input.len) input[offset + i] else @as(u8, @intCast(output_length - input.len));
                block[i] = byte ^ previous[i];
            }
            try cipher.apply(result[offset..][0..16], &block);
            previous = result[offset..][0..16].*;
        } else {
            // §28.4.2 step 3: CBC decryption before inspecting the padding.
            try cipher.apply(&block, input[offset..][0..16]);
            for (0..16) |i| result[offset + i] = block[i] ^ previous[i];
            previous = input[offset..][0..16].*;
        }
    }
    if (direction == .decrypt) {
        // Steps 4-6: inspect the entire last block before rejecting padding.
        const padding = result[result.len - 1];
        var invalid: u8 = @intFromBool(padding == 0 or padding > 16);
        for (0..16) |i| {
            const mask: u8 = 0 -% @as(u8, @intFromBool(i < padding));
            invalid |= (result[result.len - 1 - i] ^ padding) & mask;
        }
        if (invalid != 0) return error.OperationError;
        const length = result.len - padding;
        std.crypto.secureZero(u8, result[length..]);
        result = try allocator.realloc(result, length);
    }
    // §28.4.1 step 4 / §28.4.2 step 7.
    return result;
}

/// GCM returns ciphertext followed by the tag, or authenticated plaintext.
pub fn gcm(allocator: std.mem.Allocator, direction: Direction, key: []const u8, iv: []const u8, additional_data: []const u8, tag_bits: ?u8, input: []const u8) ![]u8 {
    // §29.4.1 steps 1-4 / §29.4.2 steps 1-4. Byte slices cannot exceed usize.
    const bits = tag_bits orelse 128;
    switch (bits) {
        32, 64, 96, 104, 112, 120, 128 => {},
        else => return error.OperationError,
    }
    const tag_length: usize = bits / 8;
    if (direction == .decrypt and input.len < tag_length) return error.OperationError;
    if (direction == .encrypt and input.len > (@as(u64, 1) << 39) - 256) return error.OperationError;
    if (key.len != 16 and key.len != 24 and key.len != 32) return error.OperationError;
    if (iv.len == 0) return error.OperationError; // SP 800-38D §5.2.1.1.
    const data_length = if (direction == .encrypt) input.len else input.len - tag_length;
    // SP 800-38D §5.2.1.1 also bounds the inputs to its authenticated function.
    if (data_length > (@as(u64, 1) << 36) - 32 or iv.len > std.math.maxInt(u64) / 8 or additional_data.len > std.math.maxInt(u64) / 8) return error.OperationError;
    const length = if (direction == .encrypt) std.math.add(usize, input.len, tag_length) catch return error.OperationError else input.len - tag_length;
    const result = try allocator.alloc(u8, length);
    errdefer eraseFree(allocator, result);
    // Use std.crypto's full GCM where its fixed-size nonce/tag API applies.
    if (iv.len == 12 and bits == 128 and key.len != 24) {
        inline for (.{ std.crypto.aead.aes_gcm.Aes128Gcm, std.crypto.aead.aes_gcm.Aes256Gcm }) |Gcm| {
            if (key.len == Gcm.key_length) {
                if (direction == .encrypt) {
                    Gcm.encrypt(result[0..input.len], result[input.len..][0..16], input, additional_data, iv[0..12].*, key[0..Gcm.key_length].*);
                } else {
                    Gcm.decrypt(result, input[0..length], input[length..][0..16].*, additional_data, iv[0..12].*, key[0..Gcm.key_length].*) catch return error.OperationError;
                }
                return result;
            }
        }
        unreachable;
    }
    // §29.4.1 step 6 / §29.4.2 step 8: SP 800-38D Algorithms 4 and 5,
    // using std.crypto's GHASH and AES blocks (the same-library PSA for AES-192).
    const Ghash = std.crypto.onetimeauth.Ghash;
    var cipher = try BlockCipher.init(key, .encrypt);
    defer cipher.deinit();
    var h: [16]u8 = undefined;
    defer std.crypto.secureZero(u8, &h);
    try cipher.apply(&h, &([_]u8{0} ** 16)); // Algorithm 4 step 1 / 5 step 2.
    var j0: [16]u8 = @splat(0);
    defer std.crypto.secureZero(u8, &j0);
    // Algorithm 4 step 2 / 5 step 3: GHASH derives J0 for every other IV size.
    if (iv.len == 12) {
        @memcpy(j0[0..12], iv);
        j0[15] = 1;
    } else {
        var iv_hash = Ghash.initForBlockCount(&h, iv.len / 16 + @intFromBool(iv.len % 16 != 0) + 1);
        defer std.crypto.secureZero(u8, std.mem.asBytes(&iv_hash));
        iv_hash.update(iv);
        iv_hash.pad();
        var final: [16]u8 = @splat(0);
        std.mem.writeInt(u64, final[8..16], @as(u64, iv.len) * 8, .big);
        iv_hash.update(&final);
        iv_hash.final(&j0);
    }
    if (direction == .encrypt) try gctr(&cipher, j0, result[0..data_length], input);
    const ciphertext = if (direction == .encrypt) result[0..data_length] else input[0..data_length];
    // Algorithm 4 steps 4-6 / 5 steps 5-7: authenticate padded A, C and lengths.
    const block_count = additional_data.len / 16 + @intFromBool(additional_data.len % 16 != 0) + ciphertext.len / 16 + @intFromBool(ciphertext.len % 16 != 0) + 1;
    var mac = Ghash.initForBlockCount(&h, block_count);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&mac));
    mac.update(additional_data);
    mac.pad();
    mac.update(ciphertext);
    mac.pad();
    var lengths: [16]u8 = undefined;
    std.mem.writeInt(u64, lengths[0..8], @as(u64, additional_data.len) * 8, .big);
    std.mem.writeInt(u64, lengths[8..16], @as(u64, ciphertext.len) * 8, .big);
    mac.update(&lengths);
    var tag: [16]u8 = undefined;
    defer std.crypto.secureZero(u8, &tag);
    mac.final(&tag);
    var encrypted_j0: [16]u8 = undefined;
    defer std.crypto.secureZero(u8, &encrypted_j0);
    try cipher.apply(&encrypted_j0, &j0);
    for (&tag, encrypted_j0) |*byte, mask| byte.* ^= mask;
    if (direction == .encrypt) {
        // Algorithm 4 steps 7-8: C || MSB_t(GCTR(J0, S)).
        @memcpy(result[data_length..], tag[0..tag_length]);
    } else {
        // Algorithm 5 step 8: compare the complete supplied tag in constant time.
        var supplied: [16]u8 = @splat(0);
        @memcpy(supplied[0..tag_length], input[data_length..]);
        @memset(tag[tag_length..], 0);
        if (!std.crypto.timing_safe.eql([16]u8, tag, supplied)) return error.OperationError;
        // Computing P after authenticating avoids exposing unauthenticated bytes.
        try gctr(&cipher, j0, result, ciphertext);
    }
    return result;
}

fn gctr(cipher: *const BlockCipher, initial: [16]u8, output: []u8, input: []const u8) !void {
    // SP 800-38D Algorithm 3 with ICB=inc32(J0): only the low 32 bits change.
    var counter = initial;
    defer std.crypto.secureZero(u8, &counter);
    var offset: usize = 0;
    while (offset < input.len) {
        std.mem.writeInt(u32, counter[12..16], std.mem.readInt(u32, counter[12..16], .big) +% 1, .big);
        var stream: [16]u8 = undefined;
        defer std.crypto.secureZero(u8, &stream);
        try cipher.apply(&stream, &counter);
        const count = @min(16, input.len - offset);
        for (0..count) |i| output[offset + i] = input[offset + i] ^ stream[i];
        offset += count;
    }
}

/// RFC 3394 AES-KW, with its default initial value (no KWP padding).
pub fn kw(allocator: std.mem.Allocator, direction: Direction, key: []const u8, input: []const u8) ![]u8 {
    if (!mbed.available) return error.NotSupportedError;
    // §30.3.1/2 step 1, with RFC 3394's minimum of two 64-bit key blocks.
    if (key.len != 16 and key.len != 24 and key.len != 32) return error.OperationError;
    if (input.len % 8 != 0 or input.len < (if (direction == .encrypt) @as(usize, 16) else 24)) return error.OperationError;
    const length = if (direction == .encrypt) std.math.add(usize, input.len, 8) catch return error.OperationError else input.len - 8;
    const result = try allocator.alloc(u8, length);
    errdefer eraseFree(allocator, result);
    // Steps 2-4: PSA has no AES-KW operation; use the same library's KW API.
    var context: c.mbedtls_nist_kw_context = undefined;
    c.mbedtls_nist_kw_init(&context);
    defer {
        c.mbedtls_nist_kw_free(&context);
        std.crypto.secureZero(u8, std.mem.asBytes(&context));
    }
    if (c.mbedtls_nist_kw_setkey(&context, c.MBEDTLS_CIPHER_ID_AES, key.ptr, @intCast(key.len * 8), @intFromBool(direction == .encrypt)) != 0) return error.OperationError;
    var written: usize = 0;
    const status = if (direction == .encrypt)
        c.mbedtls_nist_kw_wrap(&context, c.MBEDTLS_KW_MODE_KW, input.ptr, input.len, result.ptr, &written, result.len)
    else
        c.mbedtls_nist_kw_unwrap(&context, c.MBEDTLS_KW_MODE_KW, input.ptr, input.len, result.ptr, &written, result.len);
    if (status != 0 or written != result.len) return error.OperationError;
    return result;
}

fn eraseFree(allocator: std.mem.Allocator, bytes: []u8) void {
    std.crypto.secureZero(u8, bytes);
    allocator.free(bytes);
}

const BlockCipher = union(enum) {
    enc128: core.AesEncryptCtx(core.Aes128),
    dec128: core.AesDecryptCtx(core.Aes128),
    enc256: core.AesEncryptCtx(core.Aes256),
    dec256: core.AesDecryptCtx(core.Aes256),
    psa192: struct { key: mbed.Key, direction: Direction },

    fn init(key: []const u8, direction: Direction) !BlockCipher {
        return switch (key.len) {
            16 => if (direction == .encrypt) .{ .enc128 = core.Aes128.initEnc(key[0..16].*) } else .{ .dec128 = core.Aes128.initDec(key[0..16].*) },
            32 => if (direction == .encrypt) .{ .enc256 = core.Aes256.initEnc(key[0..32].*) } else .{ .dec256 = core.Aes256.initDec(key[0..32].*) },
            24 => if (mbed.available) .{ .psa192 = .{ .key = try mbed.Key.importAes(key, c.PSA_ALG_ECB_NO_PADDING, if (direction == .encrypt) c.PSA_KEY_USAGE_ENCRYPT else c.PSA_KEY_USAGE_DECRYPT), .direction = direction } } else error.NotSupportedError,
            else => error.OperationError,
        };
    }

    fn apply(self: *const BlockCipher, output: *[16]u8, input: *const [16]u8) !void {
        switch (self.*) {
            inline .enc128, .enc256 => |context| context.encrypt(output, input),
            inline .dec128, .dec256 => |context| context.decrypt(output, input),
            .psa192 => |context| {
                if (!mbed.available) return error.NotSupportedError;
                var written: usize = 0;
                try mbed.check(if (context.direction == .encrypt)
                    c.psa_cipher_encrypt(context.key.id, c.PSA_ALG_ECB_NO_PADDING, input, 16, output, 16, &written)
                else
                    c.psa_cipher_decrypt(context.key.id, c.PSA_ALG_ECB_NO_PADDING, input, 16, output, 16, &written));
                if (written != 16) return error.OperationError;
            },
        }
    }

    fn deinit(self: *BlockCipher) void {
        if (self.* == .psa192) self.psa192.key.deinit();
        std.crypto.secureZero(u8, std.mem.asBytes(self));
    }
};

test "AES-CTR matches SP 800-38A F.5.1" {
    var key: [16]u8 = undefined;
    var counter: [16]u8 = undefined;
    var plaintext: [64]u8 = undefined;
    var expected: [64]u8 = undefined;
    _ = try std.fmt.hexToBytes(&key, "2b7e151628aed2a6abf7158809cf4f3c");
    _ = try std.fmt.hexToBytes(&counter, "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff");
    _ = try std.fmt.hexToBytes(&plaintext, "6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c81c46a35ce411e5fbc1191a0a52eff69f2445df4f9b17ad2b417be66c3710");
    _ = try std.fmt.hexToBytes(&expected, "874d6191b620e3261bef6864990db6ce9806f66b7970fdff8617187bb9fffdff5ae4df3edbd5d35e5b4f09020db03eab1e031dda2fbe03d1792170a0f3009cee");
    const actual = try ctr(std.testing.allocator, &key, &counter, 128, &plaintext);
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualSlices(u8, &expected, actual);
    const clear = try ctr(std.testing.allocator, &key, &counter, 128, actual);
    defer std.testing.allocator.free(clear);
    try std.testing.expectEqualSlices(u8, &plaintext, clear);
}

test "AES-CTR permits counter wrap but rejects repeated counter blocks" {
    const key = [_]u8{0} ** 16;
    var counter = [_]u8{0xff} ** 16;
    const input = [_]u8{0} ** 33;
    const result = try ctr(std.testing.allocator, &key, &counter, 1, input[0..32]);
    defer std.testing.allocator.free(result);
    // The low counter bit wraps to zero; the other 127 bits remain unchanged.
    counter[15] = 0xfe;
    const second = try ctr(std.testing.allocator, &key, &counter, 128, input[0..16]);
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualSlices(u8, second, result[16..]);
    try std.testing.expectError(error.OperationError, ctr(std.testing.failing_allocator, &key, &counter, 1, &input));
    for ([_]u8{ 0, 129, 255 }) |bits| {
        try std.testing.expectError(error.OperationError, ctr(std.testing.failing_allocator, &key, &counter, bits, ""));
    }
}

test "AES-CBC first block matches SP 800-38A F.2.1 and padding roundtrips all residues" {
    var key: [16]u8 = undefined;
    var iv: [16]u8 = undefined;
    var plaintext: [16]u8 = undefined;
    var expected: [16]u8 = undefined;
    _ = try std.fmt.hexToBytes(&key, "2b7e151628aed2a6abf7158809cf4f3c");
    _ = try std.fmt.hexToBytes(&iv, "000102030405060708090a0b0c0d0e0f");
    _ = try std.fmt.hexToBytes(&plaintext, "6bc1bee22e409f96e93d7e117393172a");
    _ = try std.fmt.hexToBytes(&expected, "7649abac8119b246cee98e9b12e9197d");
    for (0..17) |length| {
        const encrypted = try cbc(std.testing.allocator, .encrypt, &key, &iv, plaintext[0..length]);
        defer std.testing.allocator.free(encrypted);
        try std.testing.expectEqual((length / 16 + 1) * 16, encrypted.len);
        if (length == 16) try std.testing.expectEqualSlices(u8, &expected, encrypted[0..16]);
        const decrypted = try cbc(std.testing.allocator, .decrypt, &key, &iv, encrypted);
        defer std.testing.allocator.free(decrypted);
        try std.testing.expectEqualSlices(u8, plaintext[0..length], decrypted);
    }
}

test "AES-GCM matches the NIST all-zero single-block vector" {
    const key = [_]u8{0} ** 16;
    const iv = [_]u8{0} ** 12;
    const plaintext = [_]u8{0} ** 16;
    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "0388dace60b6a392f328c2b971b2fe78ab6e47d42cec13bdf53a67b21257bddf");
    const encrypted = try gcm(std.testing.allocator, .encrypt, &key, &iv, "", null, &plaintext);
    defer std.testing.allocator.free(encrypted);
    try std.testing.expectEqualSlices(u8, &expected, encrypted);
    const decrypted = try gcm(std.testing.allocator, .decrypt, &key, &iv, "", 128, &expected);
    defer std.testing.allocator.free(decrypted);
    try std.testing.expectEqualSlices(u8, &plaintext, decrypted);
    for (0..expected.len) |index| {
        expected[index] ^= 1;
        try std.testing.expectError(error.OperationError, gcm(std.testing.allocator, .decrypt, &key, &iv, "", 128, &expected));
        expected[index] ^= 1;
    }
}

test "AES-GCM short tags are prefixes of the full authentication tag" {
    const key = [_]u8{0} ** 16;
    const iv = [_]u8{0} ** 12;
    var expected: [16]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "58e2fccefa7e3061367f1d57a4e7455a");
    for ([_]u8{ 32, 64, 96, 104, 112, 120, 128 }) |bits| {
        const encrypted = try gcm(std.testing.allocator, .encrypt, &key, &iv, "", bits, "");
        defer std.testing.allocator.free(encrypted);
        try std.testing.expectEqualSlices(u8, expected[0 .. bits / 8], encrypted);
        const decrypted = try gcm(std.testing.allocator, .decrypt, &key, &iv, "", bits, encrypted);
        defer std.testing.allocator.free(decrypted);
        try std.testing.expectEqual(@as(usize, 0), decrypted.len);
    }
}

test "AES-GCM derives J0 for a non-96-bit IV using the NIST validation vector" {
    // NIST AES-128, IV=128, PT=0, AAD=0, tag=128, case 0;
    // also carried by mbedTLS test_suite_gcm.aes128_en.data.
    var key: [16]u8 = undefined;
    var iv: [16]u8 = undefined;
    var expected: [16]u8 = undefined;
    _ = try std.fmt.hexToBytes(&key, "1014f74310d1718d1cc8f65f033aaf83");
    _ = try std.fmt.hexToBytes(&iv, "6bb54c9fd83c12f5ba76cc83f7650d2c");
    _ = try std.fmt.hexToBytes(&expected, "0b6b57db309eff920c8133b8691e0cac");
    for ([_]u8{ 32, 64, 96, 104, 112, 120, 128 }) |bits| {
        const encrypted = try gcm(std.testing.allocator, .encrypt, &key, &iv, "", bits, "");
        defer std.testing.allocator.free(encrypted);
        try std.testing.expectEqualSlices(u8, expected[0 .. bits / 8], encrypted);
        const decrypted = try gcm(std.testing.allocator, .decrypt, &key, &iv, "", bits, encrypted);
        defer std.testing.allocator.free(decrypted);
        try std.testing.expectEqual(@as(usize, 0), decrypted.len);
    }
}

test "AES-KW matches RFC 3394 section 4.1 and rejects tampering" {
    if (!mbed.available) return error.SkipZigTest;
    var key: [16]u8 = undefined;
    var plaintext: [16]u8 = undefined;
    var expected: [24]u8 = undefined;
    _ = try std.fmt.hexToBytes(&key, "000102030405060708090a0b0c0d0e0f");
    _ = try std.fmt.hexToBytes(&plaintext, "00112233445566778899aabbccddeeff");
    _ = try std.fmt.hexToBytes(&expected, "1fa68b0a8112b447aef34bd8fb5a7b829d3e862371d2cfe5");
    const encrypted = try kw(std.testing.allocator, .encrypt, &key, &plaintext);
    defer std.testing.allocator.free(encrypted);
    try std.testing.expectEqualSlices(u8, &expected, encrypted);
    const decrypted = try kw(std.testing.allocator, .decrypt, &key, &expected);
    defer std.testing.allocator.free(decrypted);
    try std.testing.expectEqualSlices(u8, &plaintext, decrypted);
    expected[0] ^= 1;
    try std.testing.expectError(error.OperationError, kw(std.testing.allocator, .decrypt, &key, &expected));
}

test "AES invalid parameters reject before allocating" {
    const key = [_]u8{0} ** 16;
    const fail = std.testing.failing_allocator;
    try std.testing.expectError(error.OperationError, ctr(fail, &key, key[0..15], 128, ""));
    try std.testing.expectError(error.OperationError, cbc(fail, .encrypt, &key, key[0..15], ""));
    try std.testing.expectError(error.OperationError, cbc(fail, .decrypt, &key, &key, ""));
    try std.testing.expectError(error.OperationError, cbc(fail, .decrypt, &key, &key, key[0..15]));
    for ([_]u8{ 0, 8, 40, 80, 127, 129 }) |bits| {
        try std.testing.expectError(error.OperationError, gcm(fail, .encrypt, &key, key[0..12], "", bits, ""));
    }
    try std.testing.expectError(error.OperationError, gcm(fail, .decrypt, &key, key[0..12], "", 128, key[0..15]));
    if (mbed.available) {
        try std.testing.expectError(error.OperationError, kw(fail, .encrypt, &key, key[0..15]));
        try std.testing.expectError(error.OperationError, kw(fail, .decrypt, &key, key[0..15]));
    }
}
