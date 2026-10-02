//! WebCrypto §§27-31, 33-34: secret-key generation, import and export.

const std = @import("std");
const keys = @import("key.zig");
const mbed = @import("mbed.zig");
const jwk = @import("jwk.zig");

pub fn importRaw(allocator: std.mem.Allocator, algorithm: keys.Algorithm, material: []const u8, extractable: bool, usages: keys.Usages) !keys.Slots {
    try validateImport(algorithm, usages);
    var metadata: keys.Algorithm = .{ .id = algorithm.id };
    switch (algorithm.id) {
        .aes_ctr, .aes_cbc, .aes_gcm, .aes_kw => {
            // §§27-30 Import Key step 2/raw: only the three AES key sizes.
            if (material.len != 16 and material.len != 24 and material.len != 32) return error.DataError;
            metadata.length = @intCast(material.len * 8);
            try available(algorithm.id, metadata.length.?);
        },
        .hmac => {
            // §31.6.4 steps 6-8: at most the final seven bits may be omitted.
            const full_length = std.math.mul(u32, std.math.cast(u32, material.len) orelse return error.DataError, 8) catch return error.DataError;
            if (full_length == 0) return error.DataError;
            const length = algorithm.length orelse full_length;
            if (length > full_length or length <= full_length - 8) return error.DataError;
            metadata.hash = algorithm.hash orelse return error.NotSupportedError;
            metadata.length = length;
        },
        .hkdf, .pbkdf2 => {
            // §33.4.2 step 2.2 / §34.4.2 step 3; empty key data is valid.
            try checkUsages(algorithm, usages);
            if (extractable) return error.SyntaxError;
        },
        else => return error.NotSupportedError,
    }
    // AES import steps 3-9 / HMAC steps 9-16 / KDF final slot steps.
    const result = try keys.Slots.init(allocator, .secret, extractable, metadata, usages, material);
    if (metadata.length) |bits| maskUnusedBits(@constCast(result.material), bits);
    return result;
}

pub fn generate(allocator: std.mem.Allocator, io: std.Io, algorithm: keys.Algorithm, extractable: bool, usages: keys.Usages) !keys.Slots {
    // AES/HMAC Generate Key step 1.
    if (algorithm.id == .hkdf or algorithm.id == .pbkdf2) return error.NotSupportedError;
    try checkUsages(algorithm, usages);
    // HMAC generate step 2 differs from Get Key Length's zero-length error.
    if (algorithm.id == .hmac and algorithm.length == 0) return error.OperationError;
    const bits = (try getKeyLength(algorithm)) orelse return error.NotSupportedError;
    try available(algorithm.id, bits);
    const material = try allocator.alloc(u8, (@as(usize, bits) + 7) / 8);
    defer {
        std.crypto.secureZero(u8, material);
        allocator.free(material);
    }
    // Generate steps 3-4: secure entropy, with failure reported as OperationError.
    io.randomSecure(material) catch return error.OperationError;
    maskUnusedBits(material, bits);
    // The remaining generation steps install the same native slots as import.
    var metadata = algorithm;
    metadata.length = bits;
    return importRaw(allocator, metadata, material, extractable, usages);
}

pub fn importJwk(allocator: std.mem.Allocator, algorithm: keys.Algorithm, data: jwk.Data, extractable: bool, usages: keys.Usages) !keys.Slots {
    // KDF import supports only raw; this precedes its usage/extractable checks.
    if (algorithm.id == .hkdf or algorithm.id == .pbkdf2) return error.NotSupportedError;
    if (algorithm.id == .hmac and algorithm.length == 0) return error.DataError;
    try checkUsages(algorithm, usages);
    // AES import step 2/jwk.1-4 / HMAC step 5/jwk.1-4.
    if (!std.mem.eql(u8, data.kty orelse return error.DataError, "oct")) return error.DataError;
    const material = try jwk.decode(allocator, data.k orelse return error.DataError);
    defer {
        std.crypto.secureZero(u8, material);
        allocator.free(material);
    }
    var metadata = algorithm;
    if (algorithm.id != .hmac) {
        if (material.len != 16 and material.len != 24 and material.len != 32) return error.DataError;
        metadata.length = @intCast(material.len * 8);
    }
    // AES jwk.5-8 / HMAC jwk.5-9, before HMAC's data-length checks.
    try jwk.validate(data, usages, extractable, if (algorithm.id == .hmac) "sig" else "enc", try jwk.algorithmName(metadata));
    return importRaw(allocator, algorithm, material, extractable, usages);
}

pub fn getKeyLength(algorithm: keys.Algorithm) !?u32 {
    return switch (algorithm.id) {
        .aes_ctr, .aes_cbc, .aes_gcm, .aes_kw => blk: {
            // AES Get Key Length steps 1-2.
            const bits = algorithm.length orelse return error.OperationError;
            if (bits != 128 and bits != 192 and bits != 256) return error.OperationError;
            try available(algorithm.id, bits);
            break :blk bits;
        },
        .hmac => blk: {
            // §31.6.6 steps 1-2: default is the hash block size, not digest size.
            const hash = algorithm.hash orelse return error.NotSupportedError;
            const bits = algorithm.length orelse @as(u32, @intCast(hash.blockLength() * 8));
            if (bits == 0) return error.TypeError;
            break :blk bits;
        },
        .hkdf, .pbkdf2 => null, // §§33.4.3/34.4.3 step 1.
        else => error.NotSupportedError,
    };
}

pub fn exportRaw(allocator: std.mem.Allocator, key: *const keys.Slots) ![]u8 {
    // §14.3.10 steps 6-7: support precedes extractability.
    switch (key.algorithm.id) {
        .aes_ctr, .aes_cbc, .aes_gcm, .aes_kw, .hmac => {},
        else => return error.NotSupportedError,
    }
    if (!key.extractable) return error.InvalidAccessError;
    // AES Export Key step 2/raw; HMAC steps 2-4/raw. Spare bits are already zero.
    return allocator.dupe(u8, key.material);
}

fn checkUsages(algorithm: keys.Algorithm, usages: keys.Usages) !void {
    var iterator = usages.iterator();
    while (iterator.next()) |usage| {
        const valid = switch (algorithm.id) {
            .aes_ctr, .aes_cbc, .aes_gcm => usage == .encrypt or usage == .decrypt or usage == .wrapKey or usage == .unwrapKey,
            .aes_kw => usage == .wrapKey or usage == .unwrapKey,
            .hmac => usage == .sign or usage == .verify,
            .hkdf, .pbkdf2 => usage == .deriveBits or usage == .deriveKey,
            else => return error.NotSupportedError,
        };
        if (!valid) return error.SyntaxError;
    }
}

pub fn validateImport(algorithm: keys.Algorithm, usages: keys.Usages) !void {
    // HMAC §31.6.4 step 1 precedes its usage check at step 3 and format at 5.
    if (algorithm.id == .hmac and algorithm.length == 0) return error.DataError;
    if (algorithm.id == .hkdf or algorithm.id == .pbkdf2) return;
    try checkUsages(algorithm, usages);
}

fn available(id: @import("registry.zig").Id, bits: u32) !void {
    // The system-curl configuration has no same-library mbedTLS artifact.
    if (!mbed.available and (id == .aes_kw or (id != .hmac and bits == 192))) return error.NotSupportedError;
}

fn maskUnusedBits(bytes: []u8, bits: u32) void {
    // §9: a byte sequence containing a bit sequence pads its final byte with 0s.
    if (bits % 8 != 0 and bytes.len != 0) bytes[bytes.len - 1] &= @as(u8, 0xff) << @as(u3, @intCast(8 - bits % 8));
}

test "AES raw import validates usages before key size and owns the bytes" {
    const a = std.testing.allocator;
    for ([_]@import("registry.zig").Id{ .aes_ctr, .aes_cbc, .aes_gcm, .aes_kw }) |id| {
        if (id == .aes_kw and !mbed.available) continue;
        const use = keys.Usages.initOne(if (id == .aes_kw) .wrapKey else .encrypt);
        for ([_]usize{ 16, 24, 32 }) |size| {
            if (size == 24 and !mbed.available) continue;
            var bytes = [_]u8{0x71} ** 32;
            var key = try importRaw(a, .{ .id = id }, bytes[0..size], true, use);
            defer key.deinit();
            @memset(&bytes, 0);
            try std.testing.expectEqual(@as(?u32, @intCast(size * 8)), key.algorithm.length);
            const exported = try exportRaw(a, &key);
            defer a.free(exported);
            const expected = [_]u8{0x71} ** 32;
            try std.testing.expectEqualSlices(u8, expected[0..size], exported);
        }
        try std.testing.expectError(error.SyntaxError, importRaw(a, .{ .id = id }, "", false, keys.Usages.initOne(.sign)));
        try std.testing.expectError(error.DataError, importRaw(a, .{ .id = id }, "", false, use));
        try std.testing.expectError(error.DataError, importRaw(a, .{ .id = id }, &([_]u8{0} ** 17), false, use));
    }
}

test "HMAC raw import preserves its bit length and rejects an entire discarded byte" {
    const a = std.testing.allocator;
    const use = keys.Usages.initOne(.sign);
    var key = try importRaw(a, .{ .id = .hmac, .hash = .sha256, .length = 9 }, &.{ 0x12, 0xff }, true, use);
    defer key.deinit();
    try std.testing.expectEqual(@as(?u32, 9), key.algorithm.length);
    try std.testing.expectEqualSlices(u8, &.{ 0x12, 0x80 }, key.material);
    for ([_]u32{ 0, 8, 17 }) |bits| {
        try std.testing.expectError(error.DataError, importRaw(a, .{ .id = .hmac, .hash = .sha256, .length = bits }, &.{ 1, 2 }, true, use));
    }
    try std.testing.expectError(error.DataError, importRaw(a, .{ .id = .hmac, .hash = .sha256 }, "", true, use));
    // §31.6.4 step 1 precedes its usage check at step 3.
    try std.testing.expectError(error.DataError, importRaw(a, .{ .id = .hmac, .hash = .sha256, .length = 0 }, "", true, keys.Usages.initOne(.encrypt)));
}

test "KDF base keys accept empty material but forbid extraction and unrelated usages" {
    const a = std.testing.allocator;
    for ([_]@import("registry.zig").Id{ .hkdf, .pbkdf2 }) |id| {
        var key = try importRaw(a, .{ .id = id }, "", false, keys.Usages.initOne(.deriveBits));
        defer key.deinit();
        try std.testing.expectEqual(@as(usize, 0), key.material.len);
        try std.testing.expect(!key.extractable);
        try std.testing.expectError(error.NotSupportedError, exportRaw(a, &key));
        try std.testing.expectError(error.SyntaxError, importRaw(a, .{ .id = id }, "password", true, keys.Usages.initOne(.deriveBits)));
        try std.testing.expectError(error.SyntaxError, importRaw(a, .{ .id = id }, "password", false, keys.Usages.initOne(.encrypt)));
        try std.testing.expectEqual(@as(?u32, null), try getKeyLength(.{ .id = id }));
    }
}

test "generation and derivation use the specified default and distinct zero-length errors" {
    try std.testing.expectEqual(@as(?u32, 512), try getKeyLength(.{ .id = .hmac, .hash = .sha256 }));
    try std.testing.expectEqual(@as(?u32, 1024), try getKeyLength(.{ .id = .hmac, .hash = .sha512 }));
    try std.testing.expectEqual(@as(?u32, 9), try getKeyLength(.{ .id = .hmac, .hash = .sha1, .length = 9 }));
    try std.testing.expectError(error.TypeError, getKeyLength(.{ .id = .hmac, .hash = .sha256, .length = 0 }));
    try std.testing.expectError(error.OperationError, getKeyLength(.{ .id = .aes_gcm, .length = 127 }));
    try std.testing.expectError(error.OperationError, generate(std.testing.allocator, std.Io.failing, .{ .id = .hmac, .hash = .sha256, .length = 0 }, true, keys.Usages.initOne(.sign)));
    try std.testing.expectError(error.OperationError, generate(std.testing.allocator, std.Io.failing, .{ .id = .aes_gcm, .length = 128 }, true, keys.Usages.initOne(.encrypt)));
}

test "generated AES and HMAC keys have the requested slots and bounded final bits" {
    const a = std.testing.allocator;
    var aes_key = try generate(a, std.testing.io, .{ .id = .aes_gcm, .length = 256 }, false, keys.Usages.initOne(.encrypt));
    defer aes_key.deinit();
    try std.testing.expectEqual(@as(usize, 32), aes_key.material.len);
    try std.testing.expect(!aes_key.extractable);
    try std.testing.expectError(error.InvalidAccessError, exportRaw(a, &aes_key));
    var mac = try generate(a, std.testing.io, .{ .id = .hmac, .hash = .sha512 }, true, keys.Usages.initOne(.sign));
    defer mac.deinit();
    try std.testing.expectEqual(@as(usize, 128), mac.material.len);
    try std.testing.expectEqual(@as(?u32, 1024), mac.algorithm.length);
    var odd = try generate(a, std.testing.io, .{ .id = .hmac, .hash = .sha256, .length = 9 }, true, keys.Usages.initOne(.sign));
    defer odd.deinit();
    try std.testing.expectEqual(@as(usize, 2), odd.material.len);
    try std.testing.expectEqual(@as(u8, 0), odd.material[1] & 0x7f);
}

test "secret JWK import validates its key type, material and optional metadata" {
    const a = std.testing.allocator;
    const usage = keys.Usages.initOne(.encrypt);
    const data: jwk.Data = .{ .kty = "oct", .k = "AAAAAAAAAAAAAAAAAAAAAA", .alg = "A128GCM", .key_ops = &.{"encrypt"}, .ext = true };
    var key = try importJwk(a, .{ .id = .aes_gcm }, data, true, usage);
    defer key.deinit();
    try std.testing.expectEqualSlices(u8, &([_]u8{0} ** 16), key.material);
    inline for (.{ "kty", "k" }) |member| {
        var missing = data;
        @field(missing, member) = null;
        try std.testing.expectError(error.DataError, importJwk(a, .{ .id = .aes_gcm }, missing, true, usage));
    }
    var wrong = data;
    wrong.alg = "A256GCM";
    try std.testing.expectError(error.DataError, importJwk(a, .{ .id = .aes_gcm }, wrong, true, usage));
    wrong = data;
    wrong.k = "a";
    try std.testing.expectError(error.DataError, importJwk(a, .{ .id = .aes_gcm }, wrong, true, usage));
    wrong = data;
    wrong.ext = false;
    try std.testing.expectError(error.DataError, importJwk(a, .{ .id = .aes_gcm }, wrong, true, usage));
    var mac = try importJwk(a, .{ .id = .hmac, .hash = .sha256 }, .{ .kty = "oct", .k = "AQ", .alg = "HS256" }, true, keys.Usages.initOne(.sign));
    defer mac.deinit();
    try std.testing.expectEqualSlices(u8, &.{1}, mac.material);
    try std.testing.expectError(error.NotSupportedError, importJwk(a, .{ .id = .hkdf }, data, false, keys.Usages.initOne(.deriveBits)));
}

fn importWithFailures(allocator: std.mem.Allocator) anyerror!void {
    var key = try importRaw(allocator, .{ .id = .hmac, .hash = .sha256 }, "test secret", true, keys.Usages.initOne(.sign));
    defer key.deinit();
    const exported = try exportRaw(allocator, &key);
    defer allocator.free(exported);
    try std.testing.expectEqualStrings("test secret", exported);
}

test "secret key import/export cleans up every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, importWithFailures, .{});
}
