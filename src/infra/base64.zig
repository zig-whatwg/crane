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












