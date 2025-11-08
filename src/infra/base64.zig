//! WHATWG Infra Base64 Operations
//!
//! Spec: https://infra.spec.whatwg.org/#forgiving-base64
//!
//! Forgiving Base64 encode and decode operations. The "forgiving" decode
//! algorithm strips ASCII whitespace before decoding.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Base64Error = error{
    InvalidBase64,
    OutOfMemory,
};

pub fn forgivingBase64Encode(allocator: Allocator, data: []const u8) ![]const u8 {
    const encoder = std.base64.standard.Encoder;
    const encoded_len = encoder.calcSize(data.len);

    const result = try allocator.alloc(u8, encoded_len);
    errdefer allocator.free(result);

    const encoded = encoder.encode(result, data);
    return encoded;
}

pub fn forgivingBase64Decode(allocator: Allocator, encoded: []const u8) ![]const u8 {
    var count: usize = 0;
    for (encoded) |c| {
        if (!isAsciiWhitespace(c)) count += 1;
    }

    const stripped = try allocator.alloc(u8, count);
    errdefer allocator.free(stripped);

    var idx: usize = 0;
    for (encoded) |c| {
        if (!isAsciiWhitespace(c)) {
            stripped[idx] = c;
            idx += 1;
        }
    }

    const decoder = std.base64.standard.Decoder;
    const decoded_len = try decoder.calcSizeForSlice(stripped);

    const result = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(result);

    try decoder.decode(result, stripped);
    allocator.free(stripped);

    return result;
}

const ascii_whitespace_table = blk: {
    var table: [256]bool = [_]bool{false} ** 256;
    table[0x09] = true;
    table[0x0A] = true;
    table[0x0C] = true;
    table[0x0D] = true;
    table[0x20] = true;
    break :blk table;
};

inline fn isAsciiWhitespace(c: u8) bool {
    return ascii_whitespace_table[c];
}

test "forgivingBase64Encode - empty" {
    const allocator = std.testing.allocator;
    const data = [_]u8{};
    const result = try forgivingBase64Encode(allocator, &data);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

test "forgivingBase64Encode - single byte" {
    const allocator = std.testing.allocator;
    const data = [_]u8{0x00};
    const result = try forgivingBase64Encode(allocator, &data);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("AA==", result);
}

test "forgivingBase64Encode - multiple bytes" {
    const allocator = std.testing.allocator;
    const data = "hello";
    const result = try forgivingBase64Encode(allocator, data);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("aGVsbG8=", result);
}

test "forgivingBase64Encode - no padding" {
    const allocator = std.testing.allocator;
    const data = "hel";
    const result = try forgivingBase64Encode(allocator, data);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("aGVs", result);
}

test "forgivingBase64Decode - empty" {
    const allocator = std.testing.allocator;
    const encoded = "";
    const result = try forgivingBase64Decode(allocator, encoded);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "forgivingBase64Decode - valid Base64" {
    const allocator = std.testing.allocator;
    const encoded = "aGVsbG8=";
    const result = try forgivingBase64Decode(allocator, encoded);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("hello", result);
}

test "forgivingBase64Decode - forgiving (whitespace)" {
    const allocator = std.testing.allocator;
    const encoded = "aGVs\n bG8=";
    const result = try forgivingBase64Decode(allocator, encoded);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("hello", result);
}

test "forgivingBase64Decode - forgiving (tabs and spaces)" {
    const allocator = std.testing.allocator;
    const encoded = "a G V s\t b G 8 =";
    const result = try forgivingBase64Decode(allocator, encoded);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("hello", result);
}

test "forgivingBase64Decode - invalid characters" {
    const allocator = std.testing.allocator;
    const encoded = "aGVs!bG8=";
    const result = forgivingBase64Decode(allocator, encoded);
    try std.testing.expect(std.meta.isError(result));
}

test "base64 roundtrip - ASCII" {
    const allocator = std.testing.allocator;
    const original = "hello world";

    const encoded = try forgivingBase64Encode(allocator, original);
    defer allocator.free(encoded);

    const decoded = try forgivingBase64Decode(allocator, encoded);
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings(original, decoded);
}

test "base64 roundtrip - binary data" {
    const allocator = std.testing.allocator;
    const original = [_]u8{ 0x00, 0x01, 0x02, 0xFF, 0xFE, 0xFD };

    const encoded = try forgivingBase64Encode(allocator, &original);
    defer allocator.free(encoded);

    const decoded = try forgivingBase64Decode(allocator, encoded);
    defer allocator.free(decoded);

    try std.testing.expectEqualSlices(u8, &original, decoded);
}

test "base64 - no memory leaks" {
    const allocator = std.testing.allocator;
    const data = "test data for memory leak check";

    const encoded = try forgivingBase64Encode(allocator, data);
    defer allocator.free(encoded);

    const decoded = try forgivingBase64Decode(allocator, encoded);
    defer allocator.free(decoded);
}
