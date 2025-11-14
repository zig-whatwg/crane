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
/// Spec: https://tc39.es/ecma262/#sec-sharedarraybuffer-objects
///
/// SharedArrayBuffer provides shared memory that can be accessed by multiple agents
/// (threads/workers) concurrently. All access must use atomic operations to ensure
/// memory safety and proper synchronization.
///
/// Key properties:
/// - Cannot be detached (unlike regular ArrayBuffer)
/// - Fixed size after creation
/// - Memory is shared between agents
/// - Requires atomic operations for safe concurrent access
///
/// Example:
/// ```zig
/// var sab = try SharedArrayBuffer.init(allocator, 1024);
/// defer sab.deinit(allocator);
///
/// // Atomic store
/// try sab.atomicStore(i32, 0, 42, .SeqCst);
///
/// // Atomic load
/// const value = try sab.atomicLoad(i32, 0, .SeqCst);
/// ```
pub const SharedArrayBuffer = struct {
    data: []u8,
    allocator: std.mem.Allocator,

    /// Create a new SharedArrayBuffer with the specified byte length
    ///
    /// Spec: § 25.2.1.1 AllocateSharedArrayBuffer
    ///
    /// The memory is aligned to 16 bytes to support atomic operations on all types.
    pub fn init(allocator: std.mem.Allocator, size: usize) !SharedArrayBuffer {
        // Allocate with 16-byte alignment for atomic operations
        const data = try allocator.alignedAlloc(u8, @enumFromInt(4), size); // 2^4 = 16 bytes
        @memset(data, 0);

        return SharedArrayBuffer{
            .data = data,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SharedArrayBuffer) void {
        // Must free with the same alignment we allocated with (16 bytes = 2^4)
        self.allocator.rawFree(self.data, @enumFromInt(4), @returnAddress());
    }

    /// Get the byte length of this SharedArrayBuffer
    ///
    /// Spec: § 25.2.5.1 get SharedArrayBuffer.prototype.byteLength
    pub fn byteLength(self: SharedArrayBuffer) usize {
        return self.data.len;
    }

    /// Validate that byte offset and size are within bounds and properly aligned
    fn validateAccess(self: SharedArrayBuffer, comptime T: type, byte_offset: usize) !void {
        const elem_size = @sizeOf(T);

        // Check alignment
        if (byte_offset % @alignOf(T) != 0) {
            return error.InvalidAlignment;
        }

        // Check bounds
        if (byte_offset + elem_size > self.data.len) {
            return error.OutOfBounds;
        }
    }

    /// Get a pointer to the element at the specified byte offset
    fn getPtr(self: *const SharedArrayBuffer, comptime T: type, byte_offset: usize) *T {
        return @ptrCast(@alignCast(&self.data[byte_offset]));
    }

    // ============================================================================
    // Atomic Operations
    // ============================================================================

    /// Atomically load a value from the buffer
    ///
    /// Spec: § 25.4.3 Atomics.load ( typedArray, index )
    ///
    /// Supported types: i8, u8, i16, u16, i32, u32, i64, u64
    ///
    /// Memory ordering: Uses seq_cst by default (ECMAScript requirement)
    pub fn atomicLoad(
        self: *const SharedArrayBuffer,
        comptime T: type,
        byte_offset: usize,
        comptime ordering: std.builtin.AtomicOrder,
    ) !T {
        try self.validateAccess(T, byte_offset);

        const ptr = self.getPtr(T, byte_offset);
        var atomic = std.atomic.Value(T).init(ptr.*);
        return atomic.load(ordering);
    }

    /// Atomically store a value to the buffer
    ///
    /// Spec: § 25.4.10 Atomics.store ( typedArray, index, value )
    ///
    /// Returns the stored value (ECMAScript requirement)
    pub fn atomicStore(
        self: *const SharedArrayBuffer,
        comptime T: type,
        byte_offset: usize,
        value: T,
        comptime ordering: std.builtin.AtomicOrder,
    ) !T {
        try self.validateAccess(T, byte_offset);

        const ptr = self.getPtr(T, byte_offset);
        var atomic = std.atomic.Value(T).init(ptr.*);
        atomic.store(value, ordering);
        ptr.* = atomic.raw;

        return value;
    }

    /// Atomically add to a value in the buffer
    ///
    /// Spec: § 25.4.2 Atomics.add ( typedArray, index, value )
    ///
    /// Returns the old value before the addition
    pub fn atomicAdd(
        self: *const SharedArrayBuffer,
        comptime T: type,
        byte_offset: usize,
        value: T,
        comptime ordering: std.builtin.AtomicOrder,
    ) !T {
        try self.validateAccess(T, byte_offset);

        const ptr = self.getPtr(T, byte_offset);
        var atomic = std.atomic.Value(T).init(ptr.*);
        const old = atomic.fetchAdd(value, ordering);
        ptr.* = atomic.raw;

        return old;
    }

    /// Atomically subtract from a value in the buffer
    ///
    /// Spec: § 25.4.11 Atomics.sub ( typedArray, index, value )
    ///
    /// Returns the old value before the subtraction
    pub fn atomicSub(
        self: *const SharedArrayBuffer,
        comptime T: type,
        byte_offset: usize,
        value: T,
        comptime ordering: std.builtin.AtomicOrder,
    ) !T {
        try self.validateAccess(T, byte_offset);

        const ptr = self.getPtr(T, byte_offset);
        var atomic = std.atomic.Value(T).init(ptr.*);
        const old = atomic.fetchSub(value, ordering);
        ptr.* = atomic.raw;

        return old;
    }

    /// Atomically perform bitwise AND on a value in the buffer
    ///
    /// Spec: § 25.4.1 Atomics.and ( typedArray, index, value )
    ///
    /// Returns the old value before the operation
    pub fn atomicAnd(
        self: *const SharedArrayBuffer,
        comptime T: type,
        byte_offset: usize,
        value: T,
        comptime ordering: std.builtin.AtomicOrder,
    ) !T {
        try self.validateAccess(T, byte_offset);

        const ptr = self.getPtr(T, byte_offset);
        var atomic = std.atomic.Value(T).init(ptr.*);
        const old = atomic.fetchAnd(value, ordering);
        ptr.* = atomic.raw;

        return old;
    }

    /// Atomically perform bitwise OR on a value in the buffer
    ///
    /// Spec: § 25.4.6 Atomics.or ( typedArray, index, value )
    ///
    /// Returns the old value before the operation
    pub fn atomicOr(
        self: *const SharedArrayBuffer,
        comptime T: type,
        byte_offset: usize,
        value: T,
        comptime ordering: std.builtin.AtomicOrder,
    ) !T {
        try self.validateAccess(T, byte_offset);

        const ptr = self.getPtr(T, byte_offset);
        var atomic = std.atomic.Value(T).init(ptr.*);
        const old = atomic.fetchOr(value, ordering);
        ptr.* = atomic.raw;

        return old;
    }

    /// Atomically perform bitwise XOR on a value in the buffer
    ///
    /// Spec: § 25.4.14 Atomics.xor ( typedArray, index, value )
    ///
    /// Returns the old value before the operation
    pub fn atomicXor(
        self: *const SharedArrayBuffer,
        comptime T: type,
        byte_offset: usize,
        value: T,
        comptime ordering: std.builtin.AtomicOrder,
    ) !T {
        try self.validateAccess(T, byte_offset);

        const ptr = self.getPtr(T, byte_offset);
        var atomic = std.atomic.Value(T).init(ptr.*);
        const old = atomic.fetchXor(value, ordering);
        ptr.* = atomic.raw;

        return old;
    }

    /// Atomically exchange a value in the buffer
    ///
    /// Spec: § 25.4.5 Atomics.exchange ( typedArray, index, value )
    ///
    /// Returns the old value before the exchange
    pub fn atomicExchange(
        self: *const SharedArrayBuffer,
        comptime T: type,
        byte_offset: usize,
        value: T,
        comptime ordering: std.builtin.AtomicOrder,
    ) !T {
        try self.validateAccess(T, byte_offset);

        const ptr = self.getPtr(T, byte_offset);
        var atomic = std.atomic.Value(T).init(ptr.*);
        const old = atomic.swap(value, ordering);
        ptr.* = atomic.raw;

        return old;
    }

    /// Atomically compare and exchange a value in the buffer
    ///
    /// Spec: § 25.4.4 Atomics.compareExchange ( typedArray, index, expectedValue, replacementValue )
    ///
    /// If the value at byte_offset equals expected, it is replaced with replacement.
    /// Returns the old value (before any exchange).
    pub fn atomicCompareExchange(
        self: *const SharedArrayBuffer,
        comptime T: type,
        byte_offset: usize,
        expected: T,
        replacement: T,
        comptime success_ordering: std.builtin.AtomicOrder,
        comptime failure_ordering: std.builtin.AtomicOrder,
    ) !T {
        try self.validateAccess(T, byte_offset);

        const ptr = self.getPtr(T, byte_offset);
        var atomic = std.atomic.Value(T).init(ptr.*);

        const result = atomic.cmpxchgWeak(
            expected,
            replacement,
            success_ordering,
            failure_ordering,
        );

        ptr.* = atomic.raw;

        // Return the old value (either expected if successful, or current if not)
        return result orelse expected;
    }

    /// Check if atomic operations are lock-free for the given size
    ///
    /// Spec: § 25.4.7 Atomics.isLockFree ( size )
    ///
    /// Returns true if atomic operations on values of the given size are lock-free.
    /// Lock-free operations are guaranteed to complete in a bounded number of steps.
    pub fn isLockFree(size: usize) bool {
        // Most architectures support lock-free atomics for 1, 2, 4, and 8 byte values
        return switch (size) {
            1, 2, 4, 8 => true,
            else => false,
        };
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











// ArrayBufferView Introspection API Tests


























// ============================================================================
// SharedArrayBuffer Tests
// ============================================================================

















