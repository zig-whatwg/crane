//! ArrayBufferView Introspection
//!
//! Provides runtime introspection of TypedArray and DataView objects for
//! WHATWG Streams BYOB operations.
//!
//! Spec: ECMAScript § 22.2 TypedArray Objects
//!       ECMAScript § 25.3 DataView Objects

const std = @import("std");

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

/// Extract metadata from an ArrayBufferView
///
/// This function introspects the view and extracts all relevant information.
/// In a V8 runtime, this would use V8 API calls to query the TypedArray/DataView.
///
/// For now, this is a stub that should be implemented at the V8 binding layer.
pub fn getViewMetadata(view: *const anyopaque) !ViewMetadata {
    _ = view;
    // TODO: Implement V8 introspection
    // In V8, this would:
    // 1. Check if it's a TypedArray or DataView using v8::Value::IsTypedArray(), etc.
    // 2. Cast to appropriate type
    // 3. Call GetBuffer(), ByteOffset(), ByteLength()
    // 4. Determine element size from specific typed array type
    return error.NotImplemented;
}

/// Get the element size of an ArrayBufferView in bytes
///
/// Spec: Used in ReadableByteStreamController algorithms
pub fn getViewElementSize(view: *const anyopaque) u64 {
    const metadata = getViewMetadata(view) catch {
        // Default to 1 byte (Uint8Array) if introspection fails
        return 1;
    };
    return metadata.view_type.elementSize();
}

/// Get the byte offset into the underlying ArrayBuffer
///
/// Spec: TypedArray.prototype.byteOffset
///       DataView.prototype.byteOffset
pub fn getViewByteOffset(view: *const anyopaque) u64 {
    const metadata = getViewMetadata(view) catch {
        return 0;
    };
    return metadata.byte_offset;
}

/// Get the byte length of the view
///
/// Spec: TypedArray.prototype.byteLength
///       DataView.prototype.byteLength
pub fn getViewByteLength(view: *const anyopaque) u64 {
    const metadata = getViewMetadata(view) catch {
        return 0;
    };
    return metadata.byte_length;
}

/// Check if the view's buffer is detached
///
/// Spec: IsDetachedBuffer abstract operation
pub fn isViewDetached(view: *const anyopaque) bool {
    const metadata = getViewMetadata(view) catch {
        return true; // Assume detached if we can't introspect
    };
    return metadata.detached or metadata.buffer.isDetached();
}

/// Get the view constructor type
///
/// Returns the ViewType enum identifying which TypedArray or DataView this is.
pub fn getViewConstructor(view: *const anyopaque) ViewType {
    const metadata = getViewMetadata(view) catch {
        // Default to Uint8Array if introspection fails
        return .uint8_array;
    };
    return metadata.view_type;
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
// V8 Integration Functions
// ============================================================================
//
// These functions should be implemented in src/runtime/engines/v8/ to provide
// actual V8 API integration.

/// V8-specific metadata extraction
///
/// Should be implemented in v8/bindings.zig
pub const V8ViewIntrospection = if (@hasDecl(@import("root"), "runtime")) struct {
    const v8 = @import("root").runtime.engines.v8;

    /// Extract metadata from a V8 TypedArray or DataView
    pub fn extractMetadata(isolate: anytype, value: anytype) !ViewMetadata {
        _ = isolate;
        _ = value;
        // TODO: Implement using V8 API:
        // 1. v8::Value::IsTypedArray() / IsDataView()
        // 2. Cast to v8::TypedArray / v8::DataView
        // 3. GetBuffer() -> v8::ArrayBuffer
        // 4. ByteOffset(), ByteLength()
        // 5. IsUint8Array(), IsInt16Array(), etc. for type detection
        return error.NotImplemented;
    }

    /// Determine ViewType from V8 TypedArray
    pub fn detectViewType(value: anytype) ViewType {
        _ = value;
        // TODO: Check type with:
        // - v8::Value::IsUint8Array() -> .uint8_array
        // - v8::Value::IsInt8Array() -> .int8_array
        // etc.
        return .uint8_array; // Default
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
