//! ECMAScript BigInt64Array
//!
//! Spec: ECMAScript § 22.2 TypedArray Objects

const std = @import("std");
const ArrayBuffer = @import("ArrayBuffer.zig").ArrayBuffer;

/// BigInt64Array: TypedArray of 64-bit signed BigInts
pub const BigInt64Array = struct {
    buffer: *ArrayBuffer,
    byte_offset: usize,
    length: usize,

    const Self = @This();

    pub fn init(buffer: *ArrayBuffer, byte_offset: usize, length: usize) !Self {
        if (buffer.isDetached()) return error.DetachedBuffer;
        if (byte_offset % 8 != 0) return error.InvalidOffset;
        if (byte_offset + (length * 8) > buffer.byteLength()) return error.OutOfBounds;

        return Self{
            .buffer = buffer,
            .byte_offset = byte_offset,
            .length = length,
        };
    }

    pub fn get(self: Self, index: usize) !i64 {
        if (self.buffer.isDetached()) return error.DetachedBuffer;
        if (index >= self.length) return error.IndexOutOfBounds;

        const byte_index = self.byte_offset + (index * 8);
        const bytes = self.buffer.data[byte_index..][0..8];
        return std.mem.readInt(i64, bytes, .little);
    }

    pub fn set(self: Self, index: usize, value: i64) !void {
        if (self.buffer.isDetached()) return error.DetachedBuffer;
        if (index >= self.length) return error.IndexOutOfBounds;

        const byte_index = self.byte_offset + (index * 8);
        const bytes = self.buffer.data[byte_index..][0..8];
        std.mem.writeInt(i64, bytes, value, .little);
    }
};
