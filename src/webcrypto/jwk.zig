//! WebCrypto JsonWebKey, RFC 7517 §4 and RFC 7518 §6.

const std = @import("std");
const keys = @import("key.zig");

/// Borrowed dictionary members. The conversion owner frees their storage.
pub const Data = struct {
    alg: ?[]const u8 = null,
    crv: ?[]const u8 = null,
    d: ?[]const u8 = null,
    dp: ?[]const u8 = null,
    dq: ?[]const u8 = null,
    e: ?[]const u8 = null,
    ext: ?bool = null,
    k: ?[]const u8 = null,
    key_ops: ?[]const []const u8 = null,
    kty: ?[]const u8 = null,
    n: ?[]const u8 = null,
    oth: ?[]const OtherPrime = null,
    p: ?[]const u8 = null,
    priv: ?[]const u8 = null,
    @"pub": ?[]const u8 = null,
    q: ?[]const u8 = null,
    qi: ?[]const u8 = null,
    use: ?[]const u8 = null,
    x: ?[]const u8 = null,
    y: ?[]const u8 = null,
};

pub const OtherPrime = struct { d: ?[]const u8 = null, r: ?[]const u8 = null, t: ?[]const u8 = null };

/// A converted dictionary whose string storage is independent of script.
pub const Owned = struct {
    data: Data = .{},

    pub fn deinit(self: *Owned, allocator: std.mem.Allocator) void {
        inline for (std.meta.fields(Data)) |field| {
            if (field.type == ?[]const u8) {
                if (@field(self.data, field.name)) |text| erase(allocator, text);
            }
        }
        if (self.data.key_ops) |operations| {
            for (operations) |text| erase(allocator, text);
            allocator.free(operations);
        }
        if (self.data.oth) |primes| {
            for (primes) |prime| {
                inline for (std.meta.fields(OtherPrime)) |field| {
                    if (@field(prime, field.name)) |text| erase(allocator, text);
                }
            }
            allocator.free(primes);
        }
        self.* = .{};
    }
};

fn erase(allocator: std.mem.Allocator, bytes: []const u8) void {
    std.crypto.secureZero(u8, @constCast(bytes));
    allocator.free(bytes);
}

pub fn decode(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    // RFC 7518 §6: base64url with no padding, whitespace or foreign alphabet.
    const decoder = std.base64.url_safe_no_pad.Decoder;
    const length = decoder.calcSizeForSlice(text) catch return error.DataError;
    const result = try allocator.alloc(u8, length);
    errdefer {
        std.crypto.secureZero(u8, result);
        allocator.free(result);
    }
    decoder.decode(result, text) catch return error.DataError;
    return result;
}

pub fn encode(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    const encoder = std.base64.url_safe_no_pad.Encoder;
    const result = try allocator.alloc(u8, encoder.calcSize(bytes.len));
    _ = encoder.encode(result, bytes);
    return result;
}

pub fn validate(data: Data, usages: keys.Usages, extractable: bool, expected_use: []const u8, expected_alg: ?[]const u8) !void {
    // Algorithm-specific jwk import steps: alg, use, key_ops, then ext.
    if (data.alg) |actual| if (expected_alg) |expected| {
        if (!std.mem.eql(u8, actual, expected)) return error.DataError;
    };
    if (data.use) |use| {
        if (usages.count() != 0 and !std.mem.eql(u8, use, expected_use)) return error.DataError;
    }
    if (data.key_ops) |operations| {
        // RFC 7517 §4.3 forbids every duplicate, including unknown values.
        for (operations, 0..) |operation, index| {
            for (operations[0..index]) |previous| {
                if (std.mem.eql(u8, operation, previous)) return error.DataError;
            }
            if (data.use) |use| if (std.meta.stringToEnum(keys.Usage, operation)) |usage| {
                const signature = usage == .sign or usage == .verify;
                if (std.mem.eql(u8, use, "sig") and !signature) return error.DataError;
                if (std.mem.eql(u8, use, "enc") and signature) return error.DataError;
            };
        }
        var iterator = usages.iterator();
        while (iterator.next()) |usage| {
            for (operations) |operation| {
                if (std.mem.eql(u8, operation, @tagName(usage))) break;
            } else return error.DataError;
        }
    }
    if (data.ext == false and extractable) return error.DataError;
}

pub fn exportOctet(allocator: std.mem.Allocator, key: *const keys.Slots) ![]u8 {
    // AES Export Key step 2/jwk / HMAC step 4/jwk. Metadata comes from slots.
    const algorithm = try algorithmName(key.algorithm);
    const material = try encode(allocator, key.material);
    defer {
        std.crypto.secureZero(u8, material);
        allocator.free(material);
    }
    var operations: [@typeInfo(keys.Usage).@"enum".fields.len][]const u8 = undefined;
    var count: usize = 0;
    var iterator = key.usages.iterator();
    while (iterator.next()) |usage| : (count += 1) operations[count] = @tagName(usage);
    return std.json.Stringify.valueAlloc(allocator, .{
        .kty = "oct",
        .k = material,
        .alg = algorithm,
        .key_ops = operations[0..count],
        .ext = key.extractable,
    }, .{});
}

pub fn algorithmName(algorithm: keys.Algorithm) ![]const u8 {
    return switch (algorithm.id) {
        .hmac => switch (algorithm.hash orelse return error.NotSupportedError) {
            .sha1 => "HS1",
            .sha256 => "HS256",
            .sha384 => "HS384",
            .sha512 => "HS512",
        },
        .aes_ctr => switch (algorithm.length orelse return error.DataError) {
            128 => "A128CTR",
            192 => "A192CTR",
            256 => "A256CTR",
            else => error.DataError,
        },
        .aes_cbc => switch (algorithm.length orelse return error.DataError) {
            128 => "A128CBC",
            192 => "A192CBC",
            256 => "A256CBC",
            else => error.DataError,
        },
        .aes_gcm => switch (algorithm.length orelse return error.DataError) {
            128 => "A128GCM",
            192 => "A192GCM",
            256 => "A256GCM",
            else => error.DataError,
        },
        .aes_kw => switch (algorithm.length orelse return error.DataError) {
            128 => "A128KW",
            192 => "A192KW",
            256 => "A256KW",
            else => error.DataError,
        },
        else => error.NotSupportedError,
    };
}

test "JWK base64url encodes without padding and rejects foreign alphabets" {
    const a = std.testing.allocator;
    const input = [_]u8{ 0xfb, 0xff, 0xef, 0x01 };
    const encoded = try encode(a, &input);
    defer a.free(encoded);
    try std.testing.expectEqualStrings("-__vAQ", encoded);
    const decoded = try decode(a, encoded);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
    const empty = try decode(a, "");
    defer a.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
    for ([_][]const u8{ "A", "AB=", "AB==", "a b", "+/8", "é" }) |invalid| {
        try std.testing.expectError(error.DataError, decode(a, invalid));
    }
}

test "JWK validates duplicate and missing operations, algorithm, use and ext" {
    const sign = keys.Usages.initOne(.sign);
    try validate(.{}, sign, true, "sig", "HS256");
    try validate(.{ .key_ops = &.{ "unknown", "sign" }, .ext = true, .alg = "HS256", .use = "sig" }, sign, true, "sig", "HS256");
    try std.testing.expectError(error.DataError, validate(.{ .key_ops = &.{ "unknown", "unknown", "sign" } }, sign, false, "sig", "HS256"));
    try std.testing.expectError(error.DataError, validate(.{ .key_ops = &.{"verify"} }, sign, false, "sig", "HS256"));
    try std.testing.expectError(error.DataError, validate(.{ .ext = false }, sign, true, "sig", "HS256"));
    try std.testing.expectError(error.DataError, validate(.{ .alg = "HS384" }, sign, true, "sig", "HS256"));
    try std.testing.expectError(error.DataError, validate(.{ .use = "enc" }, sign, true, "sig", "HS256"));
    try validate(.{ .use = "anything", .ext = false }, keys.Usages.initEmpty(), false, "sig", null);
}

test "JWK export has canonical algorithm and normalized native usages" {
    const a = std.testing.allocator;
    var key = try keys.Slots.init(a, .secret, true, .{ .id = .aes_gcm, .length = 128 }, try keys.usagesFromStrings(&.{ "decrypt", "encrypt", "encrypt" }), &([_]u8{0} ** 16));
    defer key.deinit();
    const json = try exportOctet(a, &key);
    defer a.free(json);
    var parsed = try std.json.parseFromSlice(std.json.Value, a, json, .{});
    defer parsed.deinit();
    const object = parsed.value.object;
    try std.testing.expectEqualStrings("oct", object.get("kty").?.string);
    try std.testing.expectEqualStrings("A128GCM", object.get("alg").?.string);
    try std.testing.expectEqualStrings("AAAAAAAAAAAAAAAAAAAAAA", object.get("k").?.string);
    try std.testing.expect(object.get("ext").?.bool);
    const ops = object.get("key_ops").?.array.items;
    try std.testing.expectEqual(@as(usize, 2), ops.len);
    try std.testing.expectEqualStrings("encrypt", ops[0].string);
    try std.testing.expectEqualStrings("decrypt", ops[1].string);
}

fn checkAllocationFailures(allocator: std.mem.Allocator) anyerror!void {
    const decoded = try decode(allocator, "-__vAQ");
    defer allocator.free(decoded);
    const encoded = try encode(allocator, decoded);
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("-__vAQ", encoded);
}

test "JWK base64 errors and success release every allocation" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, checkAllocationFailures, .{});
}
