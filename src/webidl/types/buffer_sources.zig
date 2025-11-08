//! WebIDL Buffer Source Types
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-buffer-source-types
//!
//! Buffer source types represent views into binary data. In JavaScript, these
//! are ArrayBuffer, TypedArray views, and DataView.

const std = @import("std");
const primitives = @import("primitives.zig");

/// ArrayBufferView error types
///
/// Spec: ECMAScript § 25.1 ArrayBuffer Objects, § 22.2 TypedArray Objects
pub const ArrayBufferViewError = error{
    /// Buffer has been detached/neutered
    DetachedBuffer,

    /// Byte offset not properly aligned for typed array element size
    InvalidAlignment,

    /// Offset or length extends beyond buffer bounds
    OutOfBounds,

    /// Arithmetic overflow in size calculations
    Overflow,

    /// Byte length is not a multiple of element size
    PartialElement,
};

pub const BufferSourceType = enum {
    array_buffer,
    int8_array,
    uint8_array,
    uint8_clamped_array,
    int16_array,
    uint16_array,
    int32_array,
    uint32_array,
    int64_array,
    uint64_array,
    bigint64_array,
    biguint64_array,
    float32_array,
    float64_array,
    data_view,
};

pub const ArrayBuffer = struct {
    data: []u8,
    detached: bool,

    pub fn init(allocator: std.mem.Allocator, size: usize) !ArrayBuffer {
        const data = try allocator.alloc(u8, size);
        return ArrayBuffer{
            .data = data,
            .detached = false,
        };
    }

    pub fn deinit(self: *ArrayBuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }

    pub fn detach(self: *ArrayBuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
        self.data = &[_]u8{};
        self.detached = true;
    }

    pub fn isDetached(self: ArrayBuffer) bool {
        return self.detached;
    }

    pub fn byteLength(self: ArrayBuffer) usize {
        if (self.detached) return 0;
        return self.data.len;
    }
};

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

        /// Returns a zero-copy slice view into the underlying ArrayBuffer.
        ///
        /// This provides direct access to the buffer's memory without copying,
        /// enabling convenient bulk operations like @memset, @memcpy, iteration,
        /// or passing to functions that expect slices.
        ///
        /// IMPORTANT: The returned slice is only valid while the ArrayBuffer
        /// is not detached. Using the slice after detachment is undefined behavior.
        ///
        /// Example:
        /// ```zig
        /// var buffer = try ArrayBuffer.init(allocator, 1024);
        /// defer buffer.deinit(allocator);
        /// var typed = try TypedArray(u8).init(&buffer, 0, 256);
        ///
        /// // Zero-copy view for bulk operations
        /// const view = try typed.asSlice();
        /// @memset(view, 0); // Bulk initialization
        /// for (view, 0..) |*item, i| {
        ///     item.* = @intCast(i); // Direct iteration
        /// }
        /// ```
        ///
        /// Benefits:
        /// - No copying - returns direct view into buffer memory
        /// - Ergonomic bulk operations (memset, memcpy, for loops)
        /// - Can pass to functions expecting []T slices
        /// - WebKit-style zero-copy pattern
        pub fn asSlice(self: Self) ![]T {
            if (self.buffer.isDetached()) return error.DetachedBuffer;

            const byte_start = self.byte_offset;
            const byte_end = self.byte_offset + (self.length * @sizeOf(T));
            const bytes = self.buffer.data[byte_start..byte_end];

            // Cast byte slice to typed slice
            // SAFETY: We validated alignment in init() and bounds here
            return @as([*]T, @ptrCast(@alignCast(bytes.ptr)))[0..self.length];
        }

        /// Returns a zero-copy const slice view into the underlying ArrayBuffer.
        ///
        /// Same as asSlice() but returns a read-only view.
        pub fn asConstSlice(self: Self) ![]const T {
            if (self.buffer.isDetached()) return error.DetachedBuffer;

            const byte_start = self.byte_offset;
            const byte_end = self.byte_offset + (self.length * @sizeOf(T));
            const bytes = self.buffer.data[byte_start..byte_end];

            // Cast byte slice to typed slice
            return @as([*]const T, @ptrCast(@alignCast(bytes.ptr)))[0..self.length];
        }
    };
}

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

const testing = std.testing;

test "ArrayBuffer - creation and basic operations" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 16), buffer.byteLength());
    try testing.expect(!buffer.isDetached());

    buffer.data[0] = 42;
    try testing.expectEqual(@as(u8, 42), buffer.data[0]);
}

test "ArrayBuffer - detach" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    try testing.expect(!buffer.isDetached());
    buffer.detach(testing.allocator);
    try testing.expect(buffer.isDetached());
    try testing.expectEqual(@as(usize, 0), buffer.byteLength());
}

test "TypedArray - Uint8Array operations" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    var array = try TypedArray(u8).init(&buffer, 0, 16);

    try array.set(0, 42);
    try array.set(1, 100);

    try testing.expectEqual(@as(u8, 42), try array.get(0));
    try testing.expectEqual(@as(u8, 100), try array.get(1));
}

test "TypedArray - Int32Array operations" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    var array = try TypedArray(i32).init(&buffer, 0, 4);

    try array.set(0, -100);
    try array.set(1, 200);

    try testing.expectEqual(@as(i32, -100), try array.get(0));
    try testing.expectEqual(@as(i32, 200), try array.get(1));
}

test "TypedArray - detached buffer error" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    var array = try TypedArray(u8).init(&buffer, 0, 16);
    buffer.detach(testing.allocator);

    try testing.expectError(error.DetachedBuffer, array.get(0));
    try testing.expectError(error.DetachedBuffer, array.set(0, 42));
}

test "TypedArray - zero-copy slice view (asSlice)" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    var array = try TypedArray(u32).init(&buffer, 0, 256);

    // Get zero-copy view
    const view = try array.asSlice();

    // Bulk operations on view
    @memset(view, 0);
    for (view, 0..) |*item, i| {
        item.* = @intCast(i);
    }

    // Verify through TypedArray API
    try testing.expectEqual(@as(u32, 0), try array.get(0));
    try testing.expectEqual(@as(u32, 100), try array.get(100));
    try testing.expectEqual(@as(u32, 255), try array.get(255));
}

test "TypedArray - zero-copy const slice view (asConstSlice)" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    var array = try TypedArray(u32).init(&buffer, 0, 256);

    // Set some values
    try array.set(0, 42);
    try array.set(10, 100);

    // Get const view
    const view = try array.asConstSlice();

    // Read from view
    try testing.expectEqual(@as(u32, 42), view[0]);
    try testing.expectEqual(@as(u32, 100), view[10]);
}

test "TypedArray - slice view with offset" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    // TypedArray starting at offset 256
    var array = try TypedArray(u32).init(&buffer, 256, 64);

    const view = try array.asSlice();
    view[0] = 12345;
    view[63] = 67890;

    // Verify values are written at correct offset in buffer
    try testing.expectEqual(@as(u32, 12345), try array.get(0));
    try testing.expectEqual(@as(u32, 67890), try array.get(63));
}

test "TypedArray - slice view detached buffer error" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    var array = try TypedArray(u8).init(&buffer, 0, 16);
    buffer.detach(testing.allocator);

    try testing.expectError(error.DetachedBuffer, array.asSlice());
    try testing.expectError(error.DetachedBuffer, array.asConstSlice());
}

test "DataView - uint8 operations" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    var view = try DataView.init(&buffer, 0, 16);

    try view.setUint8(0, 42);
    try view.setUint8(1, 100);

    try testing.expectEqual(@as(u8, 42), try view.getUint8(0));
    try testing.expectEqual(@as(u8, 100), try view.getUint8(1));
}

test "DataView - int32 operations with endianness" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    var view = try DataView.init(&buffer, 0, 16);

    try view.setInt32(0, -100, true);
    try view.setInt32(4, 200, false);

    try testing.expectEqual(@as(i32, -100), try view.getInt32(0, true));
    try testing.expectEqual(@as(i32, 200), try view.getInt32(4, false));
}

test "DataView - bounds checking" {
    var buffer = try ArrayBuffer.init(testing.allocator, 8);
    defer buffer.deinit(testing.allocator);

    var view = try DataView.init(&buffer, 0, 8);

    try testing.expectError(error.IndexOutOfBounds, view.getUint8(8));
    try testing.expectError(error.IndexOutOfBounds, view.getInt32(5, true));
}

// BigInt Typed Arrays

const bigint_mod = @import("bigint.zig");

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

    pub fn get(self: Self, allocator: std.mem.Allocator, index: usize) !bigint_mod.BigInt {
        if (self.buffer.isDetached()) return error.DetachedBuffer;
        if (index >= self.length) return error.IndexOutOfBounds;

        const byte_index = self.byte_offset + (index * 8);
        const bytes = self.buffer.data[byte_index..][0..8];
        const value = std.mem.readInt(i64, bytes, .little);

        return bigint_mod.BigInt.fromI64(allocator, value);
    }

    pub fn set(self: Self, index: usize, value: bigint_mod.BigInt) !void {
        if (self.buffer.isDetached()) return error.DetachedBuffer;
        if (index >= self.length) return error.IndexOutOfBounds;

        const int_value = try value.toI64();

        const byte_index = self.byte_offset + (index * 8);
        const bytes = self.buffer.data[byte_index..][0..8];
        std.mem.writeInt(i64, bytes, int_value, .little);
    }
};

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

    pub fn get(self: Self, allocator: std.mem.Allocator, index: usize) !bigint_mod.BigInt {
        if (self.buffer.isDetached()) return error.DetachedBuffer;
        if (index >= self.length) return error.IndexOutOfBounds;

        const byte_index = self.byte_offset + (index * 8);
        const bytes = self.buffer.data[byte_index..][0..8];
        const value = std.mem.readInt(u64, bytes, .little);

        return bigint_mod.BigInt.fromU64(allocator, value);
    }

    pub fn set(self: Self, index: usize, value: bigint_mod.BigInt) !void {
        if (self.buffer.isDetached()) return error.DetachedBuffer;
        if (index >= self.length) return error.IndexOutOfBounds;

        const int_value = try value.toU64();

        const byte_index = self.byte_offset + (index * 8);
        const bytes = self.buffer.data[byte_index..][0..8];
        std.mem.writeInt(u64, bytes, int_value, .little);
    }
};

test "BigInt64Array - basic operations" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    var array = try BigInt64Array.init(&buffer, 0, 2);

    var value1 = try bigint_mod.BigInt.fromI64(testing.allocator, -100);
    defer value1.deinit();
    try array.set(0, value1);

    var value2 = try bigint_mod.BigInt.fromI64(testing.allocator, 200);
    defer value2.deinit();
    try array.set(1, value2);

    var retrieved1 = try array.get(testing.allocator, 0);
    defer retrieved1.deinit();
    try testing.expectEqual(@as(i64, -100), try retrieved1.toI64());

    var retrieved2 = try array.get(testing.allocator, 1);
    defer retrieved2.deinit();
    try testing.expectEqual(@as(i64, 200), try retrieved2.toI64());
}

test "BigUint64Array - basic operations" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    var array = try BigUint64Array.init(&buffer, 0, 2);

    var value1 = try bigint_mod.BigInt.fromU64(testing.allocator, 100);
    defer value1.deinit();
    try array.set(0, value1);

    var value2 = try bigint_mod.BigInt.fromU64(testing.allocator, 200);
    defer value2.deinit();
    try array.set(1, value2);

    var retrieved1 = try array.get(testing.allocator, 0);
    defer retrieved1.deinit();
    try testing.expectEqual(@as(u64, 100), try retrieved1.toU64());

    var retrieved2 = try array.get(testing.allocator, 1);
    defer retrieved2.deinit();
    try testing.expectEqual(@as(u64, 200), try retrieved2.toU64());
}

test "BigInt64Array - detached buffer error" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    var array = try BigInt64Array.init(&buffer, 0, 2);
    buffer.detach(testing.allocator);

    try testing.expectError(error.DetachedBuffer, array.get(testing.allocator, 0));

    var value = try bigint_mod.BigInt.fromI64(testing.allocator, 42);
    defer value.deinit();
    try testing.expectError(error.DetachedBuffer, array.set(0, value));
}

test "BigUint64Array - bounds checking" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    var array = try BigUint64Array.init(&buffer, 0, 2);

    try testing.expectError(error.IndexOutOfBounds, array.get(testing.allocator, 5));

    var value = try bigint_mod.BigInt.fromU64(testing.allocator, 42);
    defer value.deinit();
    try testing.expectError(error.IndexOutOfBounds, array.set(5, value));
}

// BufferSource and AllowSharedBufferSource typedefs
// Spec: https://webidl.spec.whatwg.org/#BufferSource

/// Typed array constructor names per ECMAScript § 22.2
///
/// Spec: https://tc39.es/ecma262/#sec-typedarray-objects
pub const TypedArrayName = enum {
    Int8Array,
    Int16Array,
    Int32Array,
    Uint8Array,
    Uint16Array,
    Uint32Array,
    Uint8ClampedArray,
    BigInt64Array,
    BigUint64Array,
    Float32Array,
    Float64Array,
    // Note: DataView is not included - represented by null in getTypedArrayName()
};

/// Get element size in bytes for a typed array type
///
/// Spec: ECMAScript § 22.2.6 (Element Size Table)
pub fn getElementSizeForType(name: TypedArrayName) u8 {
    return switch (name) {
        .Int8Array, .Uint8Array, .Uint8ClampedArray => 1,
        .Int16Array, .Uint16Array => 2,
        .Int32Array, .Uint32Array, .Float32Array => 4,
        .BigInt64Array, .BigUint64Array, .Float64Array => 8,
    };
}

/// ArrayBufferView represents any TypedArray or DataView
///
/// Spec: https://webidl.spec.whatwg.org/#ArrayBufferView
pub const ArrayBufferView = union(enum) {
    int8_array: TypedArray(i8),
    uint8_array: TypedArray(u8),
    uint8_clamped_array: TypedArray(u8),
    int16_array: TypedArray(i16),
    uint16_array: TypedArray(u16),
    int32_array: TypedArray(i32),
    uint32_array: TypedArray(u32),
    int64_array: TypedArray(i64),
    uint64_array: TypedArray(u64),
    bigint64_array: BigInt64Array,
    biguint64_array: BigUint64Array,
    float32_array: TypedArray(f32),
    float64_array: TypedArray(f64),
    data_view: DataView,

    /// Get the underlying ArrayBuffer being viewed
    ///
    /// Spec: ECMAScript § 22.2.1.1 [[ViewedArrayBuffer]]
    pub fn getViewedArrayBuffer(self: ArrayBufferView) *ArrayBuffer {
        return switch (self) {
            inline else => |arr| arr.buffer,
        };
    }

    /// Get the byte offset into the buffer where this view starts
    ///
    /// Spec: ECMAScript § 22.2.1.2 [[ByteOffset]]
    pub fn getByteOffset(self: ArrayBufferView) usize {
        return switch (self) {
            inline else => |arr| arr.byte_offset,
        };
    }

    /// Get the length of this view in bytes
    ///
    /// Spec: ECMAScript § 22.2.1.3 [[ByteLength]]
    pub fn getByteLength(self: ArrayBufferView) usize {
        return switch (self) {
            .data_view => |view| view.byte_length,
            .bigint64_array => |arr| arr.length * 8,
            .biguint64_array => |arr| arr.length * 8,
            .int8_array => |arr| arr.length * 1,
            .uint8_array => |arr| arr.length * 1,
            .uint8_clamped_array => |arr| arr.length * 1,
            .int16_array => |arr| arr.length * 2,
            .uint16_array => |arr| arr.length * 2,
            .int32_array => |arr| arr.length * 4,
            .uint32_array => |arr| arr.length * 4,
            .int64_array => |arr| arr.length * 8,
            .uint64_array => |arr| arr.length * 8,
            .float32_array => |arr| arr.length * 4,
            .float64_array => |arr| arr.length * 8,
        };
    }

    /// Get the typed array constructor name, or null for DataView
    ///
    /// Spec: ECMAScript § 22.2.1.4 [[TypedArrayName]]
    /// Returns: String like "Uint8Array", "Float32Array", or null for DataView
    pub fn getTypedArrayName(self: ArrayBufferView) ?TypedArrayName {
        return switch (self) {
            .int8_array => .Int8Array,
            .int16_array => .Int16Array,
            .int32_array => .Int32Array,
            .uint8_array => .Uint8Array,
            .uint16_array => .Uint16Array,
            .uint32_array => .Uint32Array,
            .uint8_clamped_array => .Uint8ClampedArray,
            .bigint64_array => .BigInt64Array,
            .biguint64_array => .BigUint64Array,
            .float32_array => .Float32Array,
            .float64_array => .Float64Array,
            .int64_array => null, // Note: int64_array/uint64_array don't map to standard TypedArrays
            .uint64_array => null,
            .data_view => null,
        };
    }

    /// Get the size in bytes of each element in the typed array
    ///
    /// Spec: ECMAScript § 22.2.6 (Element Size Table)
    /// Returns: Element size (1, 2, 4, or 8 bytes), or 1 for DataView
    pub fn getElementSize(self: ArrayBufferView) u8 {
        return switch (self) {
            .int8_array, .uint8_array, .uint8_clamped_array => 1,
            .int16_array, .uint16_array => 2,
            .int32_array, .uint32_array, .float32_array => 4,
            .int64_array, .uint64_array, .bigint64_array, .biguint64_array, .float64_array => 8,
            .data_view => 1,
        };
    }

    /// Get the length of this view in elements (typed arrays only)
    ///
    /// Spec: ECMAScript § 22.2.1.5 [[ArrayLength]]
    /// Returns: Number of elements, or null for DataView
    pub fn getArrayLength(self: ArrayBufferView) ?usize {
        return switch (self) {
            .data_view => null,
            inline else => |arr| arr.length,
        };
    }

    /// Check if the underlying buffer has been detached/neutered
    ///
    /// Spec: ECMAScript § 25.1.5.3 IsDetachedBuffer
    pub fn isDetached(self: ArrayBufferView) bool {
        return self.getViewedArrayBuffer().isDetached();
    }

    /// Validate that a byte range is within this view's bounds
    ///
    /// Returns true if [offset, offset + length) is valid for this view
    pub fn isValidByteRange(self: ArrayBufferView, offset: usize, length: usize) bool {
        const view_offset = self.getByteOffset();
        const view_length = self.getByteLength();

        // Check for overflow in range_end calculation
        const range_end = std.math.add(usize, offset, length) catch return false;
        // Check for overflow in view_end calculation
        const view_end = std.math.add(usize, view_offset, view_length) catch return false;

        // Check bounds
        return offset >= view_offset and range_end <= view_end;
    }

    /// Returns a byte slice view of the underlying buffer data
    pub fn asBytes(self: ArrayBufferView) ![]const u8 {
        return switch (self) {
            .int8_array => |arr| blk: {
                const slice = try arr.asConstSlice();
                break :blk std.mem.sliceAsBytes(slice);
            },
            .uint8_array => |arr| try arr.asConstSlice(),
            .uint8_clamped_array => |arr| try arr.asConstSlice(),
            .int16_array => |arr| blk: {
                const slice = try arr.asConstSlice();
                break :blk std.mem.sliceAsBytes(slice);
            },
            .uint16_array => |arr| blk: {
                const slice = try arr.asConstSlice();
                break :blk std.mem.sliceAsBytes(slice);
            },
            .int32_array => |arr| blk: {
                const slice = try arr.asConstSlice();
                break :blk std.mem.sliceAsBytes(slice);
            },
            .uint32_array => |arr| blk: {
                const slice = try arr.asConstSlice();
                break :blk std.mem.sliceAsBytes(slice);
            },
            .int64_array => |arr| blk: {
                const slice = try arr.asConstSlice();
                break :blk std.mem.sliceAsBytes(slice);
            },
            .uint64_array => |arr| blk: {
                const slice = try arr.asConstSlice();
                break :blk std.mem.sliceAsBytes(slice);
            },
            .bigint64_array => |arr| arr.buffer.data[arr.byte_offset .. arr.byte_offset + (arr.length * 8)],
            .biguint64_array => |arr| arr.buffer.data[arr.byte_offset .. arr.byte_offset + (arr.length * 8)],
            .float32_array => |arr| blk: {
                const slice = try arr.asConstSlice();
                break :blk std.mem.sliceAsBytes(slice);
            },
            .float64_array => |arr| blk: {
                const slice = try arr.asConstSlice();
                break :blk std.mem.sliceAsBytes(slice);
            },
            .data_view => |view| view.buffer.data[view.byte_offset .. view.byte_offset + view.byte_length],
        };
    }
};

/// Construct a new typed array view from a buffer
///
/// Spec: ECMAScript § 22.2.4.1 TypedArray(buffer, byteOffset, length)
pub fn constructTypedArrayView(
    view_type: TypedArrayName,
    buffer: *ArrayBuffer,
    byte_offset: usize,
    byte_length: usize,
) ArrayBufferViewError!ArrayBufferView {
    // 1. Check if buffer is detached
    if (buffer.isDetached()) return error.DetachedBuffer;

    // 2. Get element size for this typed array type
    const element_size = getElementSizeForType(view_type);

    // 3. Validate alignment
    if (byte_offset % element_size != 0) return error.InvalidAlignment;

    // 4. Validate byte_length is a multiple of element size
    if (byte_length % element_size != 0) return error.PartialElement;

    // 5. Calculate element count
    const element_count = byte_length / element_size;

    // 6. Validate bounds
    const end_offset = std.math.add(usize, byte_offset, byte_length) catch return error.Overflow;
    if (end_offset > buffer.byteLength()) return error.OutOfBounds;

    // 7. Construct and return the appropriate typed array view
    return switch (view_type) {
        .Int8Array => .{ .int8_array = TypedArray(i8){ .buffer = buffer, .byte_offset = byte_offset, .length = element_count } },
        .Int16Array => .{ .int16_array = TypedArray(i16){ .buffer = buffer, .byte_offset = byte_offset, .length = element_count } },
        .Int32Array => .{ .int32_array = TypedArray(i32){ .buffer = buffer, .byte_offset = byte_offset, .length = element_count } },
        .Uint8Array => .{ .uint8_array = TypedArray(u8){ .buffer = buffer, .byte_offset = byte_offset, .length = element_count } },
        .Uint16Array => .{ .uint16_array = TypedArray(u16){ .buffer = buffer, .byte_offset = byte_offset, .length = element_count } },
        .Uint32Array => .{ .uint32_array = TypedArray(u32){ .buffer = buffer, .byte_offset = byte_offset, .length = element_count } },
        .Uint8ClampedArray => .{ .uint8_clamped_array = TypedArray(u8){ .buffer = buffer, .byte_offset = byte_offset, .length = element_count } },
        .BigInt64Array => .{ .bigint64_array = BigInt64Array{ .buffer = buffer, .byte_offset = byte_offset, .length = element_count } },
        .BigUint64Array => .{ .biguint64_array = BigUint64Array{ .buffer = buffer, .byte_offset = byte_offset, .length = element_count } },
        .Float32Array => .{ .float32_array = TypedArray(f32){ .buffer = buffer, .byte_offset = byte_offset, .length = element_count } },
        .Float64Array => .{ .float64_array = TypedArray(f64){ .buffer = buffer, .byte_offset = byte_offset, .length = element_count } },
    };
}

/// Construct a new DataView from a buffer
///
/// Spec: ECMAScript § 25.1.3.1 DataView(buffer, byteOffset, byteLength)
pub fn constructDataView(
    buffer: *ArrayBuffer,
    byte_offset: usize,
    byte_length: usize,
) ArrayBufferViewError!ArrayBufferView {
    // 1. Check if buffer is detached
    if (buffer.isDetached()) return error.DetachedBuffer;

    // 2. Validate bounds
    const end_offset = std.math.add(usize, byte_offset, byte_length) catch return error.Overflow;
    if (end_offset > buffer.byteLength()) return error.OutOfBounds;

    // 3. Construct and return DataView
    return .{ .data_view = DataView{
        .buffer = buffer,
        .byte_offset = byte_offset,
        .byte_length = byte_length,
    } };
}

/// BufferSource represents ArrayBuffer or any ArrayBufferView
///
/// typedef (ArrayBufferView or ArrayBuffer) BufferSource;
///
/// Spec: https://webidl.spec.whatwg.org/#BufferSource
pub const BufferSource = union(enum) {
    array_buffer: *ArrayBuffer,
    array_buffer_view: ArrayBufferView,

    /// Returns a byte slice view of the buffer data
    pub fn asBytes(self: BufferSource) ![]const u8 {
        return switch (self) {
            .array_buffer => |buf| {
                if (buf.isDetached()) return error.DetachedBuffer;
                return buf.data;
            },
            .array_buffer_view => |view| try view.asBytes(),
        };
    }
};

/// SharedArrayBuffer represents a shared memory buffer
///
/// Note: This is a placeholder. Full SharedArrayBuffer support requires
/// thread-safe memory access primitives and atomics.
///
/// Spec: https://tc39.es/ecma262/#sec-sharedarraybuffer-objects
pub const SharedArrayBuffer = struct {
    data: []u8,
    // TODO: Add atomic operations support when implementing full SharedArrayBuffer

    pub fn init(allocator: std.mem.Allocator, size: usize) !SharedArrayBuffer {
        const data = try allocator.alloc(u8, size);
        return SharedArrayBuffer{
            .data = data,
        };
    }

    pub fn deinit(self: *SharedArrayBuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }

    pub fn byteLength(self: SharedArrayBuffer) usize {
        return self.data.len;
    }
};

/// AllowSharedBufferSource represents ArrayBuffer, SharedArrayBuffer, or ArrayBufferView
/// with [AllowShared] extended attribute
///
/// typedef (ArrayBuffer or SharedArrayBuffer or [AllowShared] ArrayBufferView) AllowSharedBufferSource;
///
/// Spec: https://webidl.spec.whatwg.org/#AllowSharedBufferSource
pub const AllowSharedBufferSource = union(enum) {
    array_buffer: *ArrayBuffer,
    shared_array_buffer: *SharedArrayBuffer,
    array_buffer_view: ArrayBufferView,

    /// Returns a byte slice view of the buffer data
    pub fn asBytes(self: AllowSharedBufferSource) ![]const u8 {
        return switch (self) {
            .array_buffer => |buf| {
                if (buf.isDetached()) return error.DetachedBuffer;
                return buf.data;
            },
            .shared_array_buffer => |buf| buf.data,
            .array_buffer_view => |view| try view.asBytes(),
        };
    }
};

// Tests for BufferSource and AllowSharedBufferSource

test "ArrayBufferView - uint8_array asBytes" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    var array = try TypedArray(u8).init(&buffer, 0, 16);
    try array.set(0, 42);
    try array.set(1, 100);

    const view = ArrayBufferView{ .uint8_array = array };
    const bytes = try view.asBytes();

    try testing.expectEqual(@as(u8, 42), bytes[0]);
    try testing.expectEqual(@as(u8, 100), bytes[1]);
}

test "ArrayBufferView - int32_array asBytes" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    var array = try TypedArray(i32).init(&buffer, 0, 4);
    try array.set(0, -100);

    const view = ArrayBufferView{ .int32_array = array };
    const bytes = try view.asBytes();

    try testing.expectEqual(@as(usize, 16), bytes.len);
}

test "ArrayBufferView - data_view asBytes" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    var view = try DataView.init(&buffer, 0, 16);
    try view.setUint8(0, 123);

    const buffer_view = ArrayBufferView{ .data_view = view };
    const bytes = try buffer_view.asBytes();

    try testing.expectEqual(@as(u8, 123), bytes[0]);
    try testing.expectEqual(@as(usize, 16), bytes.len);
}

test "BufferSource - array_buffer variant" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    buffer.data[0] = 42;
    buffer.data[1] = 100;

    const source = BufferSource{ .array_buffer = &buffer };
    const bytes = try source.asBytes();

    try testing.expectEqual(@as(u8, 42), bytes[0]);
    try testing.expectEqual(@as(u8, 100), bytes[1]);
    try testing.expectEqual(@as(usize, 16), bytes.len);
}

test "BufferSource - array_buffer_view variant (uint8)" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    var array = try TypedArray(u8).init(&buffer, 0, 16);
    try array.set(0, 55);
    try array.set(1, 66);

    const view = ArrayBufferView{ .uint8_array = array };
    const source = BufferSource{ .array_buffer_view = view };
    const bytes = try source.asBytes();

    try testing.expectEqual(@as(u8, 55), bytes[0]);
    try testing.expectEqual(@as(u8, 66), bytes[1]);
}

test "BufferSource - detached buffer error" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    const source = BufferSource{ .array_buffer = &buffer };
    buffer.detach(testing.allocator);

    try testing.expectError(error.DetachedBuffer, source.asBytes());
}

test "SharedArrayBuffer - basic operations" {
    var shared = try SharedArrayBuffer.init(testing.allocator, 16);
    defer shared.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 16), shared.byteLength());

    shared.data[0] = 42;
    try testing.expectEqual(@as(u8, 42), shared.data[0]);
}

test "AllowSharedBufferSource - array_buffer variant" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    buffer.data[0] = 11;
    buffer.data[1] = 22;

    const source = AllowSharedBufferSource{ .array_buffer = &buffer };
    const bytes = try source.asBytes();

    try testing.expectEqual(@as(u8, 11), bytes[0]);
    try testing.expectEqual(@as(u8, 22), bytes[1]);
}

test "AllowSharedBufferSource - shared_array_buffer variant" {
    var shared = try SharedArrayBuffer.init(testing.allocator, 16);
    defer shared.deinit(testing.allocator);

    shared.data[0] = 33;
    shared.data[1] = 44;

    const source = AllowSharedBufferSource{ .shared_array_buffer = &shared };
    const bytes = try source.asBytes();

    try testing.expectEqual(@as(u8, 33), bytes[0]);
    try testing.expectEqual(@as(u8, 44), bytes[1]);
}

test "AllowSharedBufferSource - array_buffer_view variant" {
    var buffer = try ArrayBuffer.init(testing.allocator, 16);
    defer buffer.deinit(testing.allocator);

    var array = try TypedArray(u8).init(&buffer, 0, 16);
    try array.set(0, 99);
    try array.set(1, 88);

    const view = ArrayBufferView{ .uint8_array = array };
    const source = AllowSharedBufferSource{ .array_buffer_view = view };
    const bytes = try source.asBytes();

    try testing.expectEqual(@as(u8, 99), bytes[0]);
    try testing.expectEqual(@as(u8, 88), bytes[1]);
}

// ArrayBufferView Introspection API Tests

test "ArrayBufferView - getViewedArrayBuffer returns underlying buffer" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    const array = try TypedArray(u8).init(&buffer, 0, 1024);
    const view = ArrayBufferView{ .uint8_array = array };

    try testing.expectEqual(&buffer, view.getViewedArrayBuffer());
}

test "ArrayBufferView - getByteOffset returns correct offset" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    const array = try TypedArray(u8).init(&buffer, 512, 256);
    const view = ArrayBufferView{ .uint8_array = array };

    try testing.expectEqual(@as(usize, 512), view.getByteOffset());
}

test "ArrayBufferView - getByteLength returns correct length for TypedArray" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    const array = try TypedArray(u32).init(&buffer, 0, 256);
    const view = ArrayBufferView{ .uint32_array = array };

    // 256 elements * 4 bytes per element = 1024 bytes
    try testing.expectEqual(@as(usize, 1024), view.getByteLength());
}

test "ArrayBufferView - getByteLength returns correct length for DataView" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    const data_view = try DataView.init(&buffer, 512, 256);
    const view = ArrayBufferView{ .data_view = data_view };

    try testing.expectEqual(@as(usize, 256), view.getByteLength());
}

test "ArrayBufferView - getTypedArrayName returns correct type for Uint8Array" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    const array = try TypedArray(u8).init(&buffer, 0, 1024);
    const view = ArrayBufferView{ .uint8_array = array };

    try testing.expectEqual(TypedArrayName.Uint8Array, view.getTypedArrayName().?);
}

test "ArrayBufferView - getTypedArrayName returns correct type for Float32Array" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    const array = try TypedArray(f32).init(&buffer, 0, 256);
    const view = ArrayBufferView{ .float32_array = array };

    try testing.expectEqual(TypedArrayName.Float32Array, view.getTypedArrayName().?);
}

test "ArrayBufferView - getTypedArrayName returns null for DataView" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    const data_view = try DataView.init(&buffer, 0, 1024);
    const view = ArrayBufferView{ .data_view = data_view };

    try testing.expectEqual(@as(?TypedArrayName, null), view.getTypedArrayName());
}

test "ArrayBufferView - getElementSize returns correct sizes for all types" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    // 1-byte types
    const u8_view = ArrayBufferView{ .uint8_array = try TypedArray(u8).init(&buffer, 0, 1024) };
    try testing.expectEqual(@as(u8, 1), u8_view.getElementSize());

    const i8_view = ArrayBufferView{ .int8_array = try TypedArray(i8).init(&buffer, 0, 1024) };
    try testing.expectEqual(@as(u8, 1), i8_view.getElementSize());

    // 2-byte types
    const u16_view = ArrayBufferView{ .uint16_array = try TypedArray(u16).init(&buffer, 0, 512) };
    try testing.expectEqual(@as(u8, 2), u16_view.getElementSize());

    const i16_view = ArrayBufferView{ .int16_array = try TypedArray(i16).init(&buffer, 0, 512) };
    try testing.expectEqual(@as(u8, 2), i16_view.getElementSize());

    // 4-byte types
    const u32_view = ArrayBufferView{ .uint32_array = try TypedArray(u32).init(&buffer, 0, 256) };
    try testing.expectEqual(@as(u8, 4), u32_view.getElementSize());

    const i32_view = ArrayBufferView{ .int32_array = try TypedArray(i32).init(&buffer, 0, 256) };
    try testing.expectEqual(@as(u8, 4), i32_view.getElementSize());

    const f32_view = ArrayBufferView{ .float32_array = try TypedArray(f32).init(&buffer, 0, 256) };
    try testing.expectEqual(@as(u8, 4), f32_view.getElementSize());

    // 8-byte types
    const u64_view = ArrayBufferView{ .uint64_array = try TypedArray(u64).init(&buffer, 0, 128) };
    try testing.expectEqual(@as(u8, 8), u64_view.getElementSize());

    const i64_view = ArrayBufferView{ .int64_array = try TypedArray(i64).init(&buffer, 0, 128) };
    try testing.expectEqual(@as(u8, 8), i64_view.getElementSize());

    const f64_view = ArrayBufferView{ .float64_array = try TypedArray(f64).init(&buffer, 0, 128) };
    try testing.expectEqual(@as(u8, 8), f64_view.getElementSize());

    const bi64_view = ArrayBufferView{ .bigint64_array = try BigInt64Array.init(&buffer, 0, 128) };
    try testing.expectEqual(@as(u8, 8), bi64_view.getElementSize());

    const bu64_view = ArrayBufferView{ .biguint64_array = try BigUint64Array.init(&buffer, 0, 128) };
    try testing.expectEqual(@as(u8, 8), bu64_view.getElementSize());

    // DataView
    const dv_view = ArrayBufferView{ .data_view = try DataView.init(&buffer, 0, 1024) };
    try testing.expectEqual(@as(u8, 1), dv_view.getElementSize());
}

test "ArrayBufferView - getArrayLength returns correct element count" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    // Float32Array with 256 elements
    const array = try TypedArray(f32).init(&buffer, 0, 256);
    const view = ArrayBufferView{ .float32_array = array };

    try testing.expectEqual(@as(usize, 256), view.getArrayLength().?);
}

test "ArrayBufferView - getArrayLength returns null for DataView" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    const data_view = try DataView.init(&buffer, 0, 1024);
    const view = ArrayBufferView{ .data_view = data_view };

    try testing.expectEqual(@as(?usize, null), view.getArrayLength());
}

test "ArrayBufferView - isDetached returns false for attached buffer" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    const array = try TypedArray(u8).init(&buffer, 0, 1024);
    const view = ArrayBufferView{ .uint8_array = array };

    try testing.expect(!view.isDetached());
}

test "ArrayBufferView - isDetached returns true for detached buffer" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    const array = try TypedArray(u8).init(&buffer, 0, 1024);
    const view = ArrayBufferView{ .uint8_array = array };

    buffer.detach(testing.allocator);
    try testing.expect(view.isDetached());
}

test "ArrayBufferView - isValidByteRange validates ranges correctly" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    // View covers bytes 512-767 (256 bytes at offset 512)
    const array = try TypedArray(u8).init(&buffer, 512, 256);
    const view = ArrayBufferView{ .uint8_array = array };

    // Valid range within view
    try testing.expect(view.isValidByteRange(512, 256));
    try testing.expect(view.isValidByteRange(600, 100));
    try testing.expect(view.isValidByteRange(512, 0)); // Zero-length range

    // Invalid ranges
    try testing.expect(!view.isValidByteRange(0, 512)); // Before view start
    try testing.expect(!view.isValidByteRange(512, 300)); // Beyond view end
    try testing.expect(!view.isValidByteRange(400, 200)); // Starts before view
}

test "ArrayBufferView - isValidByteRange handles overflow" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    const array = try TypedArray(u8).init(&buffer, 0, 1024);
    const view = ArrayBufferView{ .uint8_array = array };

    // This would overflow if not checked
    try testing.expect(!view.isValidByteRange(std.math.maxInt(usize), 1));
}

test "constructTypedArrayView - creates valid Uint8Array view" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    const view = try constructTypedArrayView(.Uint8Array, &buffer, 0, 1024);

    try testing.expectEqual(@as(usize, 1024), view.getByteLength());
    try testing.expectEqual(TypedArrayName.Uint8Array, view.getTypedArrayName().?);
    try testing.expectEqual(@as(u8, 1), view.getElementSize());
    try testing.expectEqual(@as(usize, 1024), view.getArrayLength().?);
}

test "constructTypedArrayView - creates valid Float32Array view" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    const view = try constructTypedArrayView(.Float32Array, &buffer, 0, 1024);

    try testing.expectEqual(@as(usize, 1024), view.getByteLength());
    try testing.expectEqual(TypedArrayName.Float32Array, view.getTypedArrayName().?);
    try testing.expectEqual(@as(u8, 4), view.getElementSize());
    try testing.expectEqual(@as(usize, 256), view.getArrayLength().?); // 1024 / 4
}

test "constructTypedArrayView - validates alignment" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    // Float32Array requires 4-byte alignment
    try testing.expectError(
        error.InvalidAlignment,
        constructTypedArrayView(.Float32Array, &buffer, 1, 1020),
    );

    // Float64Array requires 8-byte alignment
    try testing.expectError(
        error.InvalidAlignment,
        constructTypedArrayView(.Float64Array, &buffer, 4, 1016),
    );

    // Uint16Array requires 2-byte alignment
    try testing.expectError(
        error.InvalidAlignment,
        constructTypedArrayView(.Uint16Array, &buffer, 1, 1022),
    );
}

test "constructTypedArrayView - validates partial elements" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    // Byte length must be multiple of element size
    try testing.expectError(
        error.PartialElement,
        constructTypedArrayView(.Uint32Array, &buffer, 0, 1023), // 1023 is not divisible by 4
    );

    try testing.expectError(
        error.PartialElement,
        constructTypedArrayView(.Float64Array, &buffer, 0, 1020), // 1020 is not divisible by 8
    );
}

test "constructTypedArrayView - validates bounds" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    // View extends beyond buffer
    try testing.expectError(
        error.OutOfBounds,
        constructTypedArrayView(.Uint8Array, &buffer, 512, 1024), // 512 + 1024 > 1024
    );
}

test "constructTypedArrayView - detects detached buffer" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    buffer.detach(testing.allocator);

    try testing.expectError(
        error.DetachedBuffer,
        constructTypedArrayView(.Uint8Array, &buffer, 0, 512),
    );
}

test "constructDataView - creates valid DataView" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    const view = try constructDataView(&buffer, 0, 1024);

    try testing.expectEqual(@as(usize, 1024), view.getByteLength());
    try testing.expectEqual(@as(?TypedArrayName, null), view.getTypedArrayName());
    try testing.expectEqual(@as(?usize, null), view.getArrayLength());
}

test "constructDataView - validates bounds" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    // View extends beyond buffer
    try testing.expectError(
        error.OutOfBounds,
        constructDataView(&buffer, 512, 1024), // 512 + 1024 > 1024
    );
}

test "constructDataView - detects detached buffer" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    buffer.detach(testing.allocator);

    try testing.expectError(
        error.DetachedBuffer,
        constructDataView(&buffer, 0, 512),
    );
}

test "getElementSizeForType - returns correct sizes" {
    try testing.expectEqual(@as(u8, 1), getElementSizeForType(.Int8Array));
    try testing.expectEqual(@as(u8, 1), getElementSizeForType(.Uint8Array));
    try testing.expectEqual(@as(u8, 1), getElementSizeForType(.Uint8ClampedArray));

    try testing.expectEqual(@as(u8, 2), getElementSizeForType(.Int16Array));
    try testing.expectEqual(@as(u8, 2), getElementSizeForType(.Uint16Array));

    try testing.expectEqual(@as(u8, 4), getElementSizeForType(.Int32Array));
    try testing.expectEqual(@as(u8, 4), getElementSizeForType(.Uint32Array));
    try testing.expectEqual(@as(u8, 4), getElementSizeForType(.Float32Array));

    try testing.expectEqual(@as(u8, 8), getElementSizeForType(.BigInt64Array));
    try testing.expectEqual(@as(u8, 8), getElementSizeForType(.BigUint64Array));
    try testing.expectEqual(@as(u8, 8), getElementSizeForType(.Float64Array));
}

test "ArrayBufferView - all typed array variants work with accessors" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit(testing.allocator);

    // Test each typed array variant
    const views = [_]ArrayBufferView{
        .{ .int8_array = try TypedArray(i8).init(&buffer, 0, 1024) },
        .{ .uint8_array = try TypedArray(u8).init(&buffer, 0, 1024) },
        .{ .uint8_clamped_array = try TypedArray(u8).init(&buffer, 0, 1024) },
        .{ .int16_array = try TypedArray(i16).init(&buffer, 0, 512) },
        .{ .uint16_array = try TypedArray(u16).init(&buffer, 0, 512) },
        .{ .int32_array = try TypedArray(i32).init(&buffer, 0, 256) },
        .{ .uint32_array = try TypedArray(u32).init(&buffer, 0, 256) },
        .{ .int64_array = try TypedArray(i64).init(&buffer, 0, 128) },
        .{ .uint64_array = try TypedArray(u64).init(&buffer, 0, 128) },
        .{ .bigint64_array = try BigInt64Array.init(&buffer, 0, 128) },
        .{ .biguint64_array = try BigUint64Array.init(&buffer, 0, 128) },
        .{ .float32_array = try TypedArray(f32).init(&buffer, 0, 256) },
        .{ .float64_array = try TypedArray(f64).init(&buffer, 0, 128) },
        .{ .data_view = try DataView.init(&buffer, 0, 1024) },
    };

    for (views) |view| {
        // All views should return the same buffer
        try testing.expectEqual(&buffer, view.getViewedArrayBuffer());

        // All views should have offset 0
        try testing.expectEqual(@as(usize, 0), view.getByteOffset());

        // All views should have byte length 1024
        try testing.expectEqual(@as(usize, 1024), view.getByteLength());

        // All views should not be detached
        try testing.expect(!view.isDetached());
    }
}
