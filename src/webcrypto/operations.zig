//! WebCrypto §14.3's native computation steps, over copied inputs only.

const std = @import("std");
const keys = @import("key.zig");
const normalize = @import("normalize.zig");
const registry = @import("registry.zig");
const secret_keys = @import("secret_keys.zig");
const jwk = @import("jwk.zig");
const aes = @import("aes.zig");
const tasks = @import("tasks.zig");
const asymmetric = @import("asymmetric_keys.zig");
const ec = @import("ec.zig");
const okp = @import("okp.zig");
const rsa = @import("rsa.zig");

pub const Format = keys.Format;
pub const Operation = enum { generate_key, import_key, export_key, encrypt, decrypt, sign, verify, derive_bits, derive_key, wrap_key, unwrap_key };

/// No JS values or live platform objects. Every allocation has one owner.
pub const Request = struct {
    operation: Operation,
    io: std.Io,
    algorithm: ?normalize.Algorithm = null,
    derived_import: ?normalize.Algorithm = null,
    derived_length: ?normalize.Algorithm = null,
    key: ?keys.Slots = null,
    other_key: ?keys.Slots = null,
    bytes: ?[]u8 = null,
    signature: ?[]u8 = null,
    dictionary: ?jwk.Owned = null,
    format: Format = .unsupported,
    extractable: bool = false,
    usages: keys.Usages = keys.Usages.initEmpty(),
    length: ?u32 = null,

    pub fn take(self: *Request) Request {
        const result = self.*;
        self.* = .{ .operation = result.operation, .io = result.io };
        return result;
    }

    pub fn deinit(self: *Request, allocator: std.mem.Allocator) void {
        inline for (.{ "algorithm", "derived_import", "derived_length" }) |field| {
            if (@field(self, field)) |*algorithm| algorithm.deinit();
        }
        if (self.key) |*key| key.deinit();
        if (self.other_key) |*key| key.deinit();
        if (self.dictionary) |*dictionary| dictionary.deinit(allocator);
        if (self.bytes) |bytes| erase(allocator, bytes);
        if (self.signature) |bytes| erase(allocator, bytes);
        self.* = undefined;
    }

    pub fn run(self: *Request, allocator: std.mem.Allocator) !tasks.Result {
        return switch (self.operation) {
            .generate_key => blk: {
                // §14.3.6 steps 8–9: generate, then reject empty private/secret usages.
                if (asymmetric.isAsymmetric(self.algorithm.?.id)) {
                    var pair = try asymmetric.generate(allocator, self.io, try metadata(&self.algorithm.?), self.extractable, self.usages);
                    errdefer {
                        pair.public_key.deinit();
                        pair.private_key.deinit();
                    }
                    try nonemptyUsages(&pair.private_key);
                    break :blk .{ .key_pair = pair };
                }
                var key = try secret_keys.generate(allocator, self.io, try metadata(&self.algorithm.?), self.extractable, self.usages);
                errdefer key.deinit();
                try nonemptyUsages(&key);
                break :blk .{ .key = key };
            },
            .import_key => .{ .key = try importKey(allocator, self.format, &self.algorithm.?, self.bytes orelse "", if (self.dictionary) |data| data.data else null, self.extractable, self.usages) },
            .export_key => try exportKey(allocator, &self.key.?, self.format),
            .encrypt, .decrypt => blk: {
                // §§14.3.1/2 steps 9-11: name, usage, then operation checks.
                const direction: aes.Direction = if (self.operation == .encrypt) .encrypt else .decrypt;
                try access(&self.key.?, self.algorithm.?.id, if (direction == .encrypt) .encrypt else .decrypt);
                break :blk .{ .bytes = try crypt(allocator, direction, &self.algorithm.?, &self.key.?, self.bytes.?) };
            },
            .sign, .verify => blk: {
                // §14.3.3 steps 9-11 / §14.3.4 steps 10-12.
                try access(&self.key.?, self.algorithm.?.id, if (self.operation == .sign) .sign else .verify);
                const key = &self.key.?;
                if (self.operation == .sign) {
                    if (asymmetric.isAsymmetric(key.algorithm.id) and key.kind != .private) return error.InvalidAccessError;
                    break :blk .{ .bytes = try switch (key.algorithm.id) {
                        .hmac => @import("hmac.zig").sign(allocator, key.algorithm.hash.?, key.material, self.bytes.?),
                        .ecdsa => ec.sign(allocator, self.io, key.algorithm.named_curve.?, self.algorithm.?.hash.?, key.material, self.bytes.?),
                        .ed25519 => okp.sign(allocator, key.material, self.bytes.?),
                        .rsa_pkcs1, .rsa_pss => rsa.sign(allocator, self.io, key, self.bytes.?, self.algorithm.?.salt_length),
                        else => error.NotSupportedError,
                    } };
                }
                if (asymmetric.isAsymmetric(key.algorithm.id) and key.kind != .public) return error.InvalidAccessError;
                break :blk .{ .boolean = switch (key.algorithm.id) {
                    .hmac => @import("hmac.zig").verify(key.algorithm.hash.?, key.material, self.signature.?, self.bytes.?),
                    .ecdsa => try ec.verify(key.algorithm.named_curve.?, self.algorithm.?.hash.?, key.material, self.signature.?, self.bytes.?),
                    .ed25519 => try okp.verify(key.material, self.signature.?, self.bytes.?),
                    .rsa_pkcs1, .rsa_pss => try rsa.verify(key, self.signature.?, self.bytes.?, self.algorithm.?.salt_length),
                    else => return error.NotSupportedError,
                } };
            },
            .derive_bits => blk: {
                // §14.3.8 steps 8-10.
                try access(&self.key.?, self.algorithm.?.id, .deriveBits);
                break :blk .{ .bytes = try derive(allocator, &self.algorithm.?, &self.key.?, self.length) };
            },
            .derive_key => blk: {
                // §14.3.7 steps 12-16: access, length, derive, then raw import.
                try access(&self.key.?, self.algorithm.?.id, .deriveKey);
                const length = try secret_keys.getKeyLength(try metadata(&self.derived_length.?));
                const bytes = try derive(allocator, &self.algorithm.?, &self.key.?, length);
                defer erase(allocator, bytes);
                break :blk .{ .key = try importKey(allocator, .raw, &self.derived_import.?, bytes, null, self.extractable, self.usages) };
            },
            .wrap_key => blk: {
                // §14.3.11 steps 9-13: wrapping access precedes export checks.
                try access(&self.key.?, self.algorithm.?.id, .wrapKey);
                var exported = try exportKey(allocator, &self.other_key.?, self.format);
                defer exported.deinit(allocator);
                const bytes = switch (exported) {
                    .bytes, .json => |bytes| bytes,
                    else => return error.OperationError,
                };
                // Step 14 permits JSON whitespace padding for AES-KW's blocks.
                if (self.format == .jwk and self.algorithm.?.id == .aes_kw and bytes.len % 8 != 0) {
                    const padded = try allocator.alloc(u8, bytes.len + 8 - bytes.len % 8);
                    defer erase(allocator, padded);
                    @memcpy(padded[0..bytes.len], bytes);
                    @memset(padded[bytes.len..], ' ');
                    break :blk .{ .bytes = try crypt(allocator, .encrypt, &self.algorithm.?, &self.key.?, padded) };
                }
                // Step 15: the native wrap operation, or its encrypt fallback.
                break :blk .{ .bytes = try crypt(allocator, .encrypt, &self.algorithm.?, &self.key.?, bytes) };
            },
            .unwrap_key => blk: {
                // §14.3.12 steps 12-14: access before decrypting the key bytes.
                try access(&self.key.?, self.algorithm.?.id, .unwrapKey);
                const bytes = try crypt(allocator, .decrypt, &self.algorithm.?, &self.key.?, self.bytes.?);
                if (self.format == .jwk) {
                    // Step 15 parses JSON/IDL on the realm thread in a later
                    // task; its copied dictionary then gets a native import job.
                    const algorithm = self.derived_import.?;
                    self.derived_import = null;
                    break :blk .{ .import_jwk = .{ .bytes = bytes, .algorithm = algorithm, .extractable = self.extractable, .usages = self.usages, .io = self.io } };
                }
                defer erase(allocator, bytes);
                break :blk .{ .key = try importKey(allocator, self.format, &self.derived_import.?, bytes, null, self.extractable, self.usages) };
            },
        };
    }
};

pub fn access(key: *const keys.Slots, id: registry.Id, usage: keys.Usage) !void {
    if (key.algorithm.id != id or !key.usages.contains(usage)) return error.InvalidAccessError;
}

pub fn importKey(allocator: std.mem.Allocator, format: Format, algorithm: *const normalize.Algorithm, bytes: []const u8, dictionary: ?jwk.Data, extractable: bool, usages: keys.Usages) !keys.Slots {
    const key_algorithm = try metadata(algorithm);
    // Algorithm-specific steps run before §14's empty-usages check.
    var key = if (asymmetric.isAsymmetric(key_algorithm.id)) try asymmetric.importKey(allocator, format, key_algorithm, bytes, dictionary, extractable, usages) else switch (format) {
        .raw => try secret_keys.importRaw(allocator, key_algorithm, bytes, extractable, usages),
        .jwk => try secret_keys.importJwk(allocator, key_algorithm, dictionary orelse return error.DataError, extractable, usages),
        else => {
            try secret_keys.validateImport(key_algorithm, usages);
            return error.NotSupportedError;
        },
    };
    errdefer key.deinit();
    // §14.3.9 steps 10-12 / deriveKey 17-19 / unwrapKey 17-19.
    try nonemptyUsages(&key);
    return key;
}

pub fn exportKey(allocator: std.mem.Allocator, key: *const keys.Slots, format: Format) !tasks.Result {
    // §14.3.10 steps 6-8; wrapping uses the identical ordered checks.
    _ = try registry.lookup(key.algorithm.id.name(), .export_key);
    if (!key.extractable) return error.InvalidAccessError;
    if (asymmetric.isAsymmetric(key.algorithm.id)) {
        const bytes = try asymmetric.exportKey(allocator, key, format);
        return if (format == .jwk) .{ .json = bytes } else .{ .bytes = bytes };
    }
    return switch (format) {
        .raw => .{ .bytes = try secret_keys.exportRaw(allocator, key) },
        .jwk => .{ .json = try jwk.exportOctet(allocator, key) },
        else => error.NotSupportedError,
    };
}

fn crypt(allocator: std.mem.Allocator, direction: aes.Direction, algorithm: *const normalize.Algorithm, key: *const keys.Slots, bytes: []const u8) ![]u8 {
    return switch (algorithm.id) {
        .aes_ctr => aes.ctr(allocator, key.material, algorithm.counter orelse return error.TypeError, @intCast(algorithm.length orelse return error.TypeError), bytes),
        .aes_cbc => aes.cbc(allocator, direction, key.material, algorithm.iv orelse return error.TypeError, bytes),
        .aes_gcm => aes.gcm(allocator, direction, key.material, algorithm.iv orelse return error.TypeError, algorithm.additional_data orelse "", algorithm.tag_length, bytes),
        .aes_kw => aes.kw(allocator, direction, key.material, bytes),
        .rsa_oaep => rsa.crypt(allocator, direction, key, bytes, algorithm.label orelse ""),
        else => error.NotSupportedError,
    };
}

fn derive(allocator: std.mem.Allocator, algorithm: *const normalize.Algorithm, key: *const keys.Slots, length: ?u32) ![]u8 {
    return switch (algorithm.id) {
        .hkdf => @import("kdf.zig").hkdf(allocator, algorithm.hash.?, key.material, algorithm.salt.?, algorithm.info.?, length),
        .pbkdf2 => @import("kdf.zig").pbkdf2(allocator, algorithm.hash.?, key.material, algorithm.salt.?, algorithm.iterations.?, length),
        .ecdh, .x25519 => blk: {
            // §§24.4.2/26.3.1 steps 1–8: peer checks, length, private base key,
            // then matching algorithms/curves, before performing agreement.
            const peer = &(algorithm.public_key orelse return error.TypeError);
            if (peer.kind != .public or peer.algorithm.id != algorithm.id) return error.InvalidAccessError;
            const maximum: u32 = if (algorithm.id == .x25519) 256 else @intCast(ec.byteLength(peer.algorithm.named_curve.?) * 8);
            if (length != null and length.? > maximum) return error.OperationError;
            if (key.kind != .private or key.algorithm.id != peer.algorithm.id) return error.InvalidAccessError;
            if (algorithm.id == .ecdh) {
                if (key.algorithm.named_curve != peer.algorithm.named_curve) return error.InvalidAccessError;
                break :blk ec.derive(allocator, key.algorithm.named_curve.?, key.material, peer.material, length);
            }
            break :blk okp.derive(allocator, key.material, peer.material, length);
        },
        else => error.NotSupportedError,
    };
}

pub fn metadata(algorithm: *const normalize.Algorithm) !keys.Algorithm {
    var result: keys.Algorithm = .{ .id = algorithm.id, .hash = algorithm.hash, .length = algorithm.length, .modulus_length = algorithm.modulus_length, .public_exponent = algorithm.public_exponent };
    if (algorithm.named_curve) |name| {
        inline for (std.meta.tags(keys.Curve)) |curve| {
            if (std.mem.eql(u8, name, curve.name())) {
                result.named_curve = curve;
                return result;
            }
        }
        // Keep an unknown curve unresolved so Generate Key's usage check still
        // precedes its unsupported-curve error. Import Key checks it first.
        return result;
    }
    return result;
}

fn nonemptyUsages(key: *const keys.Slots) !void {
    if ((key.kind == .secret or key.kind == .private) and key.usages.count() == 0) return error.SyntaxError;
}

fn erase(allocator: std.mem.Allocator, bytes: []u8) void {
    std.crypto.secureZero(u8, bytes);
    allocator.free(bytes);
}

test "export checks algorithm support before extractability and format" {
    const a = std.testing.allocator;
    var kdf = try secret_keys.importRaw(a, .{ .id = .hkdf }, "", false, keys.Usages.initOne(.deriveBits));
    defer kdf.deinit();
    try std.testing.expectError(error.NotSupportedError, exportKey(a, &kdf, .spki));
    var hmac = try secret_keys.importRaw(a, .{ .id = .hmac, .hash = .sha256 }, "key", false, keys.Usages.initOne(.sign));
    defer hmac.deinit();
    try std.testing.expectError(error.InvalidAccessError, exportKey(a, &hmac, .spki));
    try std.testing.expectError(error.InvalidAccessError, access(&hmac, .hmac, .verify));
    try std.testing.expectError(error.InvalidAccessError, access(&hmac, .aes_gcm, .sign));
}

fn checkRequestFailures(allocator: std.mem.Allocator) anyerror!void {
    var request: Request = .{ .operation = .import_key, .io = std.testing.io, .format = .raw, .extractable = true, .usages = keys.Usages.initOne(.sign), .algorithm = .{ .allocator = allocator, .id = .hmac, .hash = .sha256 } };
    defer request.deinit(allocator);
    request.bytes = try allocator.dupe(u8, "native key bytes");
    var result = try request.run(allocator);
    defer result.deinit(allocator);
    var exported = try exportKey(allocator, &result.key, .raw);
    defer exported.deinit(allocator);
    try std.testing.expectEqualStrings("native key bytes", exported.bytes);
    request.usages = keys.Usages.initEmpty();
    var unexpected = request.run(allocator) catch |err| {
        if (err == error.SyntaxError) return;
        return err;
    };
    unexpected.deinit(allocator);
    return error.TestUnexpectedResult;
}

test "native import/export requests own all inputs and results on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, checkRequestFailures, .{});
}

test "native wrap and unwrap apply key usages and preserve the RFC 3394 bytes" {
    if (!@import("mbed.zig").available) return error.SkipZigTest;
    const a = std.testing.allocator;
    var kek: [16]u8 = undefined;
    var material: [16]u8 = undefined;
    var expected: [24]u8 = undefined;
    _ = try std.fmt.hexToBytes(&kek, "000102030405060708090a0b0c0d0e0f");
    _ = try std.fmt.hexToBytes(&material, "00112233445566778899aabbccddeeff");
    _ = try std.fmt.hexToBytes(&expected, "1fa68b0a8112b447aef34bd8fb5a7b829d3e862371d2cfe5");
    var wrap: Request = .{ .operation = .wrap_key, .io = std.testing.io, .format = .raw, .algorithm = .{ .allocator = a, .id = .aes_kw } };
    defer wrap.deinit(a);
    wrap.key = try secret_keys.importRaw(a, .{ .id = .aes_kw }, &kek, false, keys.Usages.initOne(.wrapKey));
    wrap.other_key = try secret_keys.importRaw(a, .{ .id = .aes_gcm }, &material, true, keys.Usages.initOne(.encrypt));
    var wrapped = try wrap.run(a);
    defer wrapped.deinit(a);
    try std.testing.expectEqualSlices(u8, &expected, wrapped.bytes);
    var unwrap: Request = .{ .operation = .unwrap_key, .io = std.testing.io, .format = .raw, .algorithm = .{ .allocator = a, .id = .aes_kw }, .derived_import = .{ .allocator = a, .id = .aes_ctr }, .extractable = true, .usages = keys.Usages.initOne(.encrypt) };
    defer unwrap.deinit(a);
    unwrap.key = try secret_keys.importRaw(a, .{ .id = .aes_kw }, &kek, false, keys.Usages.initOne(.unwrapKey));
    unwrap.bytes = try a.dupe(u8, wrapped.bytes);
    var unwrapped = try unwrap.run(a);
    defer unwrapped.deinit(a);
    try std.testing.expectEqualSlices(u8, &material, unwrapped.key.material);
    try std.testing.expectEqual(registry.Id.aes_ctr, unwrapped.key.algorithm.id);
}
