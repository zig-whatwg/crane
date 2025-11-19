//! ECMAScript TypedArray
//!
//! Spec: ECMAScript § 22.2 TypedArray Objects
//!
//! TypedArrays provide an array-like view of an underlying binary data buffer.

const std = @import("std");
const ArrayBuffer = @import("ArrayBuffer.zig").ArrayBuffer;

/// Generic TypedArray providing a typed view into an ArrayBuffer
///
/// Spec: ECMAScript § 22.2.4 The TypedArray Constructors
pub fn TypedArray(comptime T: type) type {
    return struct {
        buffer: *ArrayBuffer,
        byte_offset: usize,
        length: usize,

        const Self = @This();

        pub fn init(buffer: *ArrayBuffer, byte_offset: usize, length: usize) !Self {
            if (buffer.isDetached()) return error.DetachedBuffer;
            if (byte_offset % @sizeOf(T) != 0) return error.InvalidOffset;
            if (byte_offset + (length * @sizeOf(T)) > buffer.byteLength()) return error.OutOfBounds;

            return Self{
                .buffer = buffer,
                .byte_offset = byte_offset,
                .length = length,
            };
        }

        pub fn get(self: Self, index: usize) !T {
            if (self.buffer.isDetached()) return error.DetachedBuffer;
            if (index >= self.length) return error.IndexOutOfBounds;

            const byte_index = self.byte_offset + (index * @sizeOf(T));
            const bytes = self.buffer.data[byte_index..][0..@sizeOf(T)];
            return std.mem.bytesToValue(T, bytes);
        }

        pub fn set(self: Self, index: usize, value: T) !void {
            if (self.buffer.isDetached()) return error.DetachedBuffer;
            if (index >= self.length) return error.IndexOutOfBounds;

            const byte_index = self.byte_offset + (index * @sizeOf(T));
            const bytes = self.buffer.data[byte_index..][0..@sizeOf(T)];
            std.mem.writeInt(T, bytes, value, .little);
        }

        /// Returns a zero-copy slice view into the underlying ArrayBuffer
        pub fn asSlice(self: Self) ![]T {
            if (self.buffer.isDetached()) return error.DetachedBuffer;

            const byte_start = self.byte_offset;
            const byte_end = self.byte_offset + (self.length * @sizeOf(T));
            const bytes = self.buffer.data[byte_start..byte_end];

            return @as([*]T, @ptrCast(@alignCast(bytes.ptr)))[0..self.length];
        }

        /// Returns a zero-copy const slice view into the underlying ArrayBuffer
        pub fn asConstSlice(self: Self) ![]const T {
            if (self.buffer.isDetached()) return error.DetachedBuffer;

            const byte_start = self.byte_offset;
            const byte_end = self.byte_offset + (self.length * @sizeOf(T));
            const bytes = self.buffer.data[byte_start..byte_end];

            return @as([*]const T, @ptrCast(@alignCast(bytes.ptr)))[0..self.length];
        }
    };
}
