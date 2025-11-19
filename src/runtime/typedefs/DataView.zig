//! ECMAScript DataView
//!
//! Spec: ECMAScript § 25.3 DataView Objects
//!
//! The DataView view provides a low-level interface for reading and writing
//! multiple number types in a binary ArrayBuffer, without having to care about
//! the platform's endianness.

const std = @import("std");
const ArrayBuffer = @import("ArrayBuffer.zig").ArrayBuffer;

/// DataView provides a view into an ArrayBuffer with methods to read/write
/// multiple number types at arbitrary byte offsets
///
/// Spec: ECMAScript § 25.3.2 The DataView Constructor
pub const DataView = struct {
    buffer: *ArrayBuffer,
    byte_offset: usize,
    byte_length: usize,

    pub fn init(buffer: *ArrayBuffer, byte_offset: usize, byte_length: usize) !DataView {
        if (buffer.isDetached()) return error.DetachedBuffer;
        if (byte_offset + byte_length > buffer.byteLength()) return error.OutOfBounds;

        return DataView{
            .buffer = buffer,
            .byte_offset = byte_offset,
            .byte_length = byte_length,
        };
    }

    pub fn getUint8(self: DataView, byte_offset: usize) !u8 {
        if (self.buffer.isDetached()) return error.DetachedBuffer;
        if (byte_offset >= self.byte_length) return error.IndexOutOfBounds;
        return self.buffer.data[self.byte_offset + byte_offset];
    }

    pub fn setUint8(self: DataView, byte_offset: usize, value: u8) !void {
        if (self.buffer.isDetached()) return error.DetachedBuffer;
        if (byte_offset >= self.byte_length) return error.IndexOutOfBounds;
        self.buffer.data[self.byte_offset + byte_offset] = value;
    }

    pub fn getInt32(self: DataView, byte_offset: usize, little_endian: bool) !i32 {
        if (self.buffer.isDetached()) return error.DetachedBuffer;
        if (byte_offset + 4 > self.byte_length) return error.IndexOutOfBounds;

        const bytes = self.buffer.data[self.byte_offset + byte_offset ..][0..4];
        const endian: std.builtin.Endian = if (little_endian) .little else .big;
        return std.mem.readInt(i32, bytes, endian);
    }

    pub fn setInt32(self: DataView, byte_offset: usize, value: i32, little_endian: bool) !void {
        if (self.buffer.isDetached()) return error.DetachedBuffer;
        if (byte_offset + 4 > self.byte_length) return error.IndexOutOfBounds;

        const bytes = self.buffer.data[self.byte_offset + byte_offset ..][0..4];
        const endian: std.builtin.Endian = if (little_endian) .little else .big;
        std.mem.writeInt(i32, bytes, value, endian);
    }
};
