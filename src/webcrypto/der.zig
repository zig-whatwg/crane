//! WebCrypto §9 ASN.1 parsing, with X.690 DER's canonical lengths and integers.

const std = @import("std");

/// Borrowed views: key-format parsers retain no allocation or engine resource.
pub const Reader = struct {
    remaining: []const u8,

    pub fn read(self: *Reader, tag: u8) ![]const u8 {
        const data = self.remaining;
        if (data.len < 2 or data[0] != tag) return error.DataError;
        // X.690 §§8.1.3, 10.1: definite length in the fewest possible octets.
        var length: usize = data[1];
        var offset: usize = 2;
        if (data[1] & 0x80 != 0) {
            const count = data[1] & 0x7f;
            if (count == 0 or count > @sizeOf(usize) or count > data.len - offset) return error.DataError;
            if (data[offset] == 0) return error.DataError;
            length = 0;
            for (data[offset..][0..count]) |byte| length = (length << 8) | byte;
            if (length < 128) return error.DataError;
            offset += count;
        }
        if (length > data.len - offset) return error.DataError;
        const content = data[offset..][0..length];
        self.remaining = data[offset + length ..];
        return content;
    }

    pub fn integer(self: *Reader) ![]const u8 {
        // X.690 §8.3: minimal signed encoding; key components are non-negative.
        const content = try self.read(2);
        if (content.len == 0 or content[0] & 0x80 != 0) return error.DataError;
        if (content.len > 1 and content[0] == 0) {
            if (content[1] & 0x80 == 0) return error.DataError;
            return content[1..];
        }
        return content;
    }

    /// Crypto key BIT STRINGs encode octets and therefore have zero unused bits.
    pub fn bits(self: *Reader) ![]const u8 {
        // X.690 §§8.6, 10.2: primitive BIT STRING, then its unused-bit count.
        const content = try self.read(3);
        if (content.len == 0 or content[0] != 0) return error.DataError;
        return content[1..];
    }

    pub fn finish(self: Reader) !void {
        // WebCrypto §9 parse-an-ASN.1-structure step 5: exactData defaults true.
        if (self.remaining.len != 0) return error.DataError;
    }
};

pub fn sequence(bytes: []const u8) !Reader {
    var outer: Reader = .{ .remaining = bytes };
    const body = try outer.read(0x30);
    try outer.finish();
    return .{ .remaining = body };
}

/// Concatenate content fragments into one DER element. Caller owns the bytes.
pub fn encode(allocator: std.mem.Allocator, tag: u8, parts: []const []const u8) ![]u8 {
    // X.690 §§8.1.3, 10.1: canonical definite-length encoding.
    var length: usize = 0;
    for (parts) |part| length = std.math.add(usize, length, part.len) catch return error.OperationError;
    var length_octets: usize = 0;
    if (length >= 128) {
        var remaining = length;
        while (remaining != 0) : (remaining >>= 8) length_octets += 1;
    }
    const header_length = 2 + length_octets;
    const total = std.math.add(usize, header_length, length) catch return error.OperationError;
    const result = try allocator.alloc(u8, total);
    result[0] = tag;
    if (length_octets == 0) {
        result[1] = @intCast(length);
    } else {
        result[1] = 0x80 | @as(u8, @intCast(length_octets));
        var remaining = length;
        var index = header_length;
        while (index > 2) {
            index -= 1;
            result[index] = @truncate(remaining);
            remaining >>= 8;
        }
    }
    var offset = header_length;
    for (parts) |part| {
        @memcpy(result[offset..][0..part.len], part);
        offset += part.len;
    }
    return result;
}

pub fn encodeInteger(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    // X.690 §8.3: strip redundant zeros, then protect a positive sign bit.
    var bytes = value;
    while (bytes.len > 1 and bytes[0] == 0) bytes = bytes[1..];
    if (bytes.len == 0) return encode(allocator, 2, &.{&.{0}});
    if (bytes[0] & 0x80 != 0) return encode(allocator, 2, &.{ &.{0}, bytes });
    return encode(allocator, 2, &.{bytes});
}

test "DER enforces exact data and canonical definite lengths" {
    const empty = try sequence(&.{ 0x30, 0 });
    try empty.finish();
    for ([_][]const u8{
        "",                  &.{0x30},                  &.{ 0x30, 0, 0 }, &.{ 0x30, 0x80, 0, 0 },
        &.{ 0x30, 0x81, 0 }, &.{ 0x30, 0x82, 0, 0x80 }, &.{ 0x30, 0xff }, &.{ 0x30, 3, 2, 1 },
        &.{ 0x31, 0 },
    }) |invalid| try std.testing.expectError(error.DataError, sequence(invalid));
    var length128: [131]u8 = @splat(0);
    length128[0..3].* = .{ 0x30, 0x81, 0x80 };
    const parsed = try sequence(&length128);
    try std.testing.expectEqual(@as(usize, 128), parsed.remaining.len);
    try std.testing.expectError(error.DataError, parsed.finish());
}

test "DER unsigned integers reject empty negative and overlong encodings" {
    for ([_][]const u8{ &.{ 2, 0 }, &.{ 2, 1, 0x80 }, &.{ 2, 2, 0, 1 }, &.{ 2, 2, 0xff, 0xff } }) |invalid| {
        var reader: Reader = .{ .remaining = invalid };
        try std.testing.expectError(error.DataError, reader.integer());
    }
    var reader: Reader = .{ .remaining = &.{ 2, 2, 0, 0x80, 2, 1, 0 } };
    try std.testing.expectEqualSlices(u8, &.{0x80}, try reader.integer());
    try std.testing.expectEqualSlices(u8, &.{0}, try reader.integer());
    try reader.finish();
}

test "DER crypto bit strings require complete octets" {
    var valid: Reader = .{ .remaining = &.{ 3, 3, 0, 0x12, 0xff } };
    try std.testing.expectEqualSlices(u8, &.{ 0x12, 0xff }, try valid.bits());
    try valid.finish();
    for ([_][]const u8{ &.{ 3, 0 }, &.{ 3, 1, 1 }, &.{ 3, 2, 1, 0xfe }, &.{ 0x23, 0 } }) |invalid| {
        var reader: Reader = .{ .remaining = invalid };
        try std.testing.expectError(error.DataError, reader.bits());
    }
}

fn roundTrip(allocator: std.mem.Allocator) anyerror!void {
    const integer = try encodeInteger(allocator, &.{ 0, 0, 0x80, 0xff });
    defer allocator.free(integer);
    try std.testing.expectEqualSlices(u8, &.{ 2, 3, 0, 0x80, 0xff }, integer);
    const encoded = try encode(allocator, 0x30, &.{integer});
    defer allocator.free(encoded);
    var reader = try sequence(encoded);
    try std.testing.expectEqualSlices(u8, &.{ 0x80, 0xff }, try reader.integer());
    try reader.finish();
    const body = [_]u8{0} ** 256;
    const long = try encode(allocator, 4, &.{&body});
    defer allocator.free(long);
    try std.testing.expectEqualSlices(u8, &.{ 4, 0x82, 1, 0 }, long[0..4]);
    var long_reader: Reader = .{ .remaining = long };
    try std.testing.expectEqualSlices(u8, &body, try long_reader.read(4));
    try long_reader.finish();
}

test "DER writers round-trip positive integers and long lengths without leaks" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, roundTrip, .{});
}
