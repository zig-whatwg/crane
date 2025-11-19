//! ECMAScript BigUint64Array
//!
//! Spec: ECMAScript § 22.2 TypedArray Objects

const std = @import("std");
const ArrayBuffer = @import("ArrayBuffer.zig").ArrayBuffer;

/// BigUint64Array: TypedArray of 64-bit unsigned BigInts
pub const BigUint64Array = struct {
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

    pub fn get(self: Self, index: usize) !u64 {
        if (self.buffer.isDetached()) return error.DetachedBuffer;
        if (index >= self.length) return error.IndexOutOfBounds;

        const byte_index = self.byte_offset + (index * 8);
        const bytes = self.buffer.data[byte_index..][0..8];
        return std.mem.readInt(u64, bytes, .little);
    }

    pub fn set(self: Self, index: usize, value: u64) !void {
        if (self.buffer.isDetached()) return error.DetachedBuffer;
        if (index >= self.length) return error.IndexOutOfBounds;

        const byte_index = self.byte_offset + (index * 8);
        const bytes = self.buffer.data[byte_index..][0..8];
        std.mem.writeInt(u64, bytes, value, .little);
    }
};
