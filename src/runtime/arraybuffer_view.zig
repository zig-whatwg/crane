//! ArrayBufferView Introspection
//!
//! Provides runtime introspection of TypedArray and DataView objects for
//! WHATWG Streams BYOB operations.
//!
//! Spec: ECMAScript § 22.2 TypedArray Objects
//!       ECMAScript § 25.3 DataView Objects

const std = @import("std");
const v8_mod = @import("v8");
const ffi = v8_mod.ffi;
const pointer_tag = v8_mod.pointer_tag;

/// Simple ArrayBuffer representation for Streams BYOB operations
///
/// This matches the structure used in streams/internal/pull_into_descriptor.zig
/// We define it here to avoid circular dependencies.
pub const ArrayBuffer = struct {
    data: []u8,
    byte_length: usize,
    detached: bool = false,

    pub fn init(allocator: std.mem.Allocator, byte_length: usize) !ArrayBuffer {
        const data = try allocator.alloc(u8, byte_length);
        return .{
            .data = data,
            .byte_length = byte_length,
        };
    }

    pub fn deinit(self: *ArrayBuffer, allocator: std.mem.Allocator) void {
        if (!self.detached) {
            allocator.free(self.data);
        }
    }

    pub fn isDetached(self: *const ArrayBuffer) bool {
        return self.detached;
    }

    pub fn transfer(self: *ArrayBuffer) !ArrayBuffer {
        const new_buffer = ArrayBuffer{
            .data = self.data,
            .byte_length = self.byte_length,
            .detached = false,
        };
        self.detached = true;
        self.data = &[_]u8{};
        self.byte_length = 0;
        return new_buffer;
    }
};

/// TypedArray element types
pub const ViewType = enum {
    int8_array,
    uint8_array,
    uint8_clamped_array,
    int16_array,
    uint16_array,
    int32_array,
    uint32_array,
    float32_array,
    float64_array,
    bigint64_array,
    biguint64_array,
    data_view,

    /// Get element size in bytes for this view type
    pub fn elementSize(self: ViewType) u64 {
        return switch (self) {
            .int8_array, .uint8_array, .uint8_clamped_array => 1,
            .int16_array, .uint16_array => 2,
            .int32_array, .uint32_array, .float32_array => 4,
            .float64_array, .bigint64_array, .biguint64_array => 8,
            .data_view => 1, // DataView has no fixed element size
        };
    }
};

/// ArrayBufferView metadata
///
/// Contains all information needed to work with a TypedArray or DataView
pub const ViewMetadata = struct {
    buffer: *ArrayBuffer,
    byte_offset: u64,
    byte_length: u64,
    view_type: ViewType,
    detached: bool,
};

// ============================================================================
// V8 Integration Helpers
// ============================================================================

/// Determine ViewType from V8 Value
fn getViewTypeFromV8(value: *ffi.Value) ?ViewType {
    if (ffi.v8_Value_IsInt8Array(value)) return .int8_array;
    if (ffi.v8_Value_IsUint8Array(value)) return .uint8_array;
    if (ffi.v8_Value_IsUint8ClampedArray(value)) return .uint8_clamped_array;
    if (ffi.v8_Value_IsInt16Array(value)) return .int16_array;
    if (ffi.v8_Value_IsUint16Array(value)) return .uint16_array;
    if (ffi.v8_Value_IsInt32Array(value)) return .int32_array;
    if (ffi.v8_Value_IsUint32Array(value)) return .uint32_array;
    if (ffi.v8_Value_IsFloat32Array(value)) return .float32_array;
    if (ffi.v8_Value_IsFloat64Array(value)) return .float64_array;
    if (ffi.v8_Value_IsBigInt64Array(value)) return .bigint64_array;
    if (ffi.v8_Value_IsBigUint64Array(value)) return .biguint64_array;
    if (ffi.v8_Value_IsDataView(value)) return .data_view;
    return null;
}

/// Extract metadata from an ArrayBufferView
///
/// This function introspects the view using V8 APIs.
pub fn getViewMetadata(view: *const anyopaque) !ViewMetadata {
    const untagged = pointer_tag.untagPointer(view);
    const v8_value: *ffi.Value = @ptrCast(untagged.ptr);

    // Determine view type
    const view_type = getViewTypeFromV8(v8_value) orelse return error.TypeError;

    // Get buffer
    const buffer = ffi.v8_TypedArray_Buffer(v8_value) orelse return error.InvalidState;

    // Check if detached
    const detached = ffi.v8_ArrayBuffer_IsDetached(buffer);

    // Get view properties
    const byte_offset = ffi.v8_TypedArray_ByteOffset(v8_value);
    const byte_length = ffi.v8_TypedArray_ByteLength(v8_value);

    // Create a simple ArrayBuffer wrapper (just for metadata, doesn't own the buffer)
    var array_buffer = ArrayBuffer{
        .data = &[_]u8{}, // We don't actually need the data pointer
        .byte_length = ffi.v8_ArrayBuffer_ByteLength(buffer),
        .detached = detached,
    };

    // Dispose the buffer handle (we got our info)
    ffi.v8_ArrayBuffer_Dispose(buffer);

    return ViewMetadata{
        .buffer = &array_buffer,
        .byte_offset = @intCast(byte_offset),
        .byte_length = @intCast(byte_length),
        .view_type = view_type,
        .detached = detached,
    };
}

/// Get the element size of an ArrayBufferView in bytes
///
/// Spec: Used in ReadableByteStreamController algorithms
pub fn getViewElementSize(view: *const anyopaque) u64 {
    const untagged = pointer_tag.untagPointer(view);
    const v8_value: *ffi.Value = @ptrCast(untagged.ptr);
    const view_type = getViewTypeFromV8(v8_value) orelse return 1;
    return view_type.elementSize();
}

/// Get the byte offset into the underlying ArrayBuffer
///
/// Spec: TypedArray.prototype.byteOffset
///       DataView.prototype.byteOffset
pub fn getViewByteOffset(view: *const anyopaque) u64 {
    const untagged = pointer_tag.untagPointer(view);
    const v8_value: *ffi.Value = @ptrCast(untagged.ptr);
    const offset = ffi.v8_TypedArray_ByteOffset(v8_value);
    return @intCast(offset);
}

/// Get the byte length of the view
///
/// Spec: TypedArray.prototype.byteLength
///       DataView.prototype.byteLength
pub fn getViewByteLength(view: *const anyopaque) u64 {
    const untagged = pointer_tag.untagPointer(view);
    const v8_value: *ffi.Value = @ptrCast(untagged.ptr);
    const length = ffi.v8_TypedArray_ByteLength(v8_value);
    return @intCast(length);
}

/// Check if the view's buffer is detached
///
/// Spec: IsDetachedBuffer abstract operation
pub fn isViewDetached(view: *const anyopaque) bool {
    const untagged = pointer_tag.untagPointer(view);
    const v8_value: *ffi.Value = @ptrCast(untagged.ptr);

    // Get buffer and check if detached
    const buffer = ffi.v8_TypedArray_Buffer(v8_value) orelse return true;
    defer ffi.v8_ArrayBuffer_Dispose(buffer);

    return ffi.v8_ArrayBuffer_IsDetached(buffer);
}

/// Get the byte length of the view's underlying ArrayBuffer
///
/// Spec: ArrayBuffer.prototype.byteLength (of the viewed buffer)
pub fn getViewBufferByteLength(view: *const anyopaque) u64 {
    const untagged = pointer_tag.untagPointer(view);
    const v8_value: *ffi.Value = @ptrCast(untagged.ptr);

    // Get buffer
    const buffer = ffi.v8_TypedArray_Buffer(v8_value) orelse return 0;
    defer ffi.v8_ArrayBuffer_Dispose(buffer);

    return @intCast(ffi.v8_ArrayBuffer_ByteLength(buffer));
}

/// Get the view constructor type
///
/// Returns the ViewType enum identifying which TypedArray or DataView this is.
pub fn getViewConstructor(view: *const anyopaque) ViewType {
    const untagged = pointer_tag.untagPointer(view);
    const v8_value: *ffi.Value = @ptrCast(untagged.ptr);
    return getViewTypeFromV8(v8_value) orelse .uint8_array;
}

/// Extract the underlying ArrayBuffer from a view
///
/// Spec: TypedArray.prototype.buffer
///       DataView.prototype.buffer
pub fn extractViewBuffer(allocator: std.mem.Allocator, view: *const anyopaque) !*ArrayBuffer {
    _ = allocator;
    const metadata = try getViewMetadata(view);
    return metadata.buffer;
}

// ============================================================================
// TypedArray Construction
// ============================================================================

/// Create a V8 TypedArray or DataView from buffer data
///
/// This function creates a V8 TypedArray view over an ArrayBuffer.
/// Used by BYOB stream controllers to return views to JavaScript.
///
/// @param isolate - V8 isolate handle
/// @param view_type - Type of view to create (Uint8Array, Int16Array, etc.)
/// @param buffer - ArrayBuffer handle
/// @param byte_offset - Offset into the buffer
/// @param length - Number of elements (for TypedArray) or bytes (for DataView)
/// @return V8 Value handle to the new view, or null on error
pub fn createView(
    isolate: *ffi.Isolate,
    view_type: ViewType,
    buffer: *ffi.ArrayBuffer,
    byte_offset: usize,
    length: usize,
) ?*ffi.Value {
    return switch (view_type) {
        .int8_array => ffi.v8_Int8Array_New(isolate, buffer, byte_offset, length),
        .uint8_array => ffi.v8_Uint8Array_New(isolate, buffer, byte_offset, length),
        .uint8_clamped_array => ffi.v8_Uint8ClampedArray_New(isolate, buffer, byte_offset, length),
        .int16_array => ffi.v8_Int16Array_New(isolate, buffer, byte_offset, length),
        .uint16_array => ffi.v8_Uint16Array_New(isolate, buffer, byte_offset, length),
        .int32_array => ffi.v8_Int32Array_New(isolate, buffer, byte_offset, length),
        .uint32_array => ffi.v8_Uint32Array_New(isolate, buffer, byte_offset, length),
        .float32_array => ffi.v8_Float32Array_New(isolate, buffer, byte_offset, length),
        .float64_array => ffi.v8_Float64Array_New(isolate, buffer, byte_offset, length),
        .bigint64_array => ffi.v8_BigInt64Array_New(isolate, buffer, byte_offset, length),
        .biguint64_array => ffi.v8_BigUint64Array_New(isolate, buffer, byte_offset, length),
        .data_view => ffi.v8_DataView_New(isolate, buffer, byte_offset, length),
    };
}

/// Create a Uint8Array view - convenience function for the most common case
///
/// BYOB streams most commonly use Uint8Array for raw byte operations.
pub fn createUint8Array(
    isolate: *ffi.Isolate,
    buffer: *ffi.ArrayBuffer,
    byte_offset: usize,
    length: usize,
) ?*ffi.Value {
    return ffi.v8_Uint8Array_New(isolate, buffer, byte_offset, length);
}

// ============================================================================
// V8 Integration Functions
// ============================================================================

/// V8-specific metadata extraction
///
/// This struct provides type-safe V8 integration when available.
pub const V8ViewIntrospection = if (@hasDecl(@import("root"), "runtime")) struct {
    const v8 = @import("root").runtime.engines.v8;

    /// Extract metadata from a V8 TypedArray or DataView
    ///
    /// Uses the V8 FFI functions to get buffer details.
    pub fn extractMetadata(isolate: *ffi.Isolate, value: *ffi.Value) !ViewMetadata {
        _ = isolate;

        // Determine view type from V8 value
        const view_type = getViewTypeFromV8(value) orelse return error.TypeError;

        // Get buffer reference
        const buffer_handle = ffi.v8_TypedArray_Buffer(value) orelse return error.InvalidState;

        // Check detachment
        const detached = ffi.v8_ArrayBuffer_IsDetached(buffer_handle);

        // Get view properties
        const byte_offset = ffi.v8_TypedArray_ByteOffset(value);
        const byte_length = ffi.v8_TypedArray_ByteLength(value);

        // Create wrapper (doesn't own the buffer)
        var array_buffer = ArrayBuffer{
            .data = &[_]u8{},
            .byte_length = ffi.v8_ArrayBuffer_ByteLength(buffer_handle),
            .detached = detached,
        };

        // Dispose buffer handle
        ffi.v8_ArrayBuffer_Dispose(buffer_handle);

        return ViewMetadata{
            .buffer = &array_buffer,
            .byte_offset = @intCast(byte_offset),
            .byte_length = @intCast(byte_length),
            .view_type = view_type,
            .detached = detached,
        };
    }

    /// Determine ViewType from V8 TypedArray
    pub fn detectViewType(value: *ffi.Value) ViewType {
        return getViewTypeFromV8(value) orelse .uint8_array;
    }
} else struct {};

// ============================================================================
// Test Helpers
// ============================================================================

/// Create a test Uint8Array view for testing
pub fn createTestUint8Array(allocator: std.mem.Allocator, size: usize) !ViewMetadata {
    const buffer = try allocator.create(ArrayBuffer);
    errdefer allocator.destroy(buffer);

    buffer.* = try ArrayBuffer.init(allocator, size);

    return ViewMetadata{
        .buffer = buffer,
        .byte_offset = 0,
        .byte_length = size,
        .view_type = .uint8_array,
        .detached = false,
    };
}

/// Create a test view with specific offset and length
pub fn createTestView(
    allocator: std.mem.Allocator,
    view_type: ViewType,
    buffer_size: usize,
    byte_offset: u64,
    byte_length: u64,
) !ViewMetadata {
    const buffer = try allocator.create(ArrayBuffer);
    errdefer allocator.destroy(buffer);

    buffer.* = try ArrayBuffer.init(allocator, buffer_size);

    return ViewMetadata{
        .buffer = buffer,
        .byte_offset = byte_offset,
        .byte_length = byte_length,
        .view_type = view_type,
        .detached = false,
    };
}

test "ViewType element sizes" {
    const testing = std.testing;

    try testing.expectEqual(@as(u64, 1), ViewType.uint8_array.elementSize());
    try testing.expectEqual(@as(u64, 1), ViewType.int8_array.elementSize());
    try testing.expectEqual(@as(u64, 2), ViewType.uint16_array.elementSize());
    try testing.expectEqual(@as(u64, 2), ViewType.int16_array.elementSize());
    try testing.expectEqual(@as(u64, 4), ViewType.uint32_array.elementSize());
    try testing.expectEqual(@as(u64, 4), ViewType.int32_array.elementSize());
    try testing.expectEqual(@as(u64, 4), ViewType.float32_array.elementSize());
    try testing.expectEqual(@as(u64, 8), ViewType.float64_array.elementSize());
    try testing.expectEqual(@as(u64, 8), ViewType.bigint64_array.elementSize());
    try testing.expectEqual(@as(u64, 8), ViewType.biguint64_array.elementSize());
}

test "Create test view" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const metadata = try createTestUint8Array(allocator, 256);
    defer {
        metadata.buffer.deinit();
        allocator.destroy(metadata.buffer);
    }

    try testing.expectEqual(@as(u64, 0), metadata.byte_offset);
    try testing.expectEqual(@as(u64, 256), metadata.byte_length);
    try testing.expectEqual(ViewType.uint8_array, metadata.view_type);
    try testing.expect(!metadata.detached);
}
