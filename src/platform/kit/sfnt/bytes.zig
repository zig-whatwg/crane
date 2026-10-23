//! Big-endian reading over untrusted font data: every read is bounds-checked
//! and a short read is `error.Corrupt` - a font is used whole or not at all.

const std = @import("std");

pub const Error = error{Corrupt};

/// A tag as the font stores it (four bytes, big-endian).
pub fn tag(comptime text: *const [4]u8) u32 {
    return std.mem.readInt(u32, text, .big);
}

/// A cursor over `data`.
pub const Reader = struct {
    data: []const u8,
    pos: usize = 0,

    pub fn init(data: []const u8) Reader {
        return .{ .data = data };
    }

    pub fn at(data: []const u8, pos: usize) Error!Reader {
        if (pos > data.len) return error.Corrupt;
        return .{ .data = data, .pos = pos };
    }

    pub fn remaining(self: Reader) usize {
        return self.data.len - self.pos;
    }

    pub fn skip(self: *Reader, n: usize) Error!void {
        if (self.remaining() < n) return error.Corrupt;
        self.pos += n;
    }

    pub fn take(self: *Reader, n: usize) Error![]const u8 {
        if (self.remaining() < n) return error.Corrupt;
        defer self.pos += n;
        return self.data[self.pos..][0..n];
    }

    pub fn u8_(self: *Reader) Error!u8 {
        return (try self.take(1))[0];
    }

    pub fn u16_(self: *Reader) Error!u16 {
        return std.mem.readInt(u16, (try self.take(2))[0..2], .big);
    }

    pub fn i16_(self: *Reader) Error!i16 {
        return std.mem.readInt(i16, (try self.take(2))[0..2], .big);
    }

    pub fn u24_(self: *Reader) Error!u24 {
        return std.mem.readInt(u24, (try self.take(3))[0..3], .big);
    }

    pub fn u32_(self: *Reader) Error!u32 {
        return std.mem.readInt(u32, (try self.take(4))[0..4], .big);
    }
};

/// The u16 at `pos` in `data`, or Corrupt.
pub fn u16At(data: []const u8, pos: usize) Error!u16 {
    if (pos > data.len or data.len - pos < 2) return error.Corrupt;
    return std.mem.readInt(u16, data[pos..][0..2], .big);
}

pub fn i16At(data: []const u8, pos: usize) Error!i16 {
    return @bitCast(try u16At(data, pos));
}

pub fn u32At(data: []const u8, pos: usize) Error!u32 {
    if (pos > data.len or data.len - pos < 4) return error.Corrupt;
    return std.mem.readInt(u32, data[pos..][0..4], .big);
}

/// `data[offset..][0..length]`, or Corrupt when it runs past the end.
pub fn slice(data: []const u8, offset: usize, length: usize) Error![]const u8 {
    if (offset > data.len or data.len - offset < length) return error.Corrupt;
    return data[offset..][0..length];
}

pub fn round4(n: u64) u64 {
    return (n + 3) & ~@as(u64, 3);
}

test "a short read is Corrupt, never past the end" {
    var r = Reader.init(&.{ 0x12, 0x34, 0x56 });
    try std.testing.expectEqual(@as(u16, 0x1234), try r.u16_());
    try std.testing.expectError(error.Corrupt, r.u16_());
    try std.testing.expectEqual(@as(u8, 0x56), try r.u8_());
    try std.testing.expectError(error.Corrupt, r.u8_());
    try std.testing.expectError(error.Corrupt, slice("abc", 2, 2));
    try std.testing.expectError(error.Corrupt, u32At("abc", 0));
    try std.testing.expectEqual(@as(u64, 8), round4(5));
}
