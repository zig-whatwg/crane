//! Pull-into descriptor for BYOB read operations
//!
//! Tracks buffer state during BYOB reads.
//!
//! Spec: § 4.7.4 "Pull-into descriptor"
//! https://streams.spec.whatwg.org/#pull-into-descriptor

const std = @import("std");

/// Placeholder for ArrayBuffer
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

    pub fn byteLength(self: *const ArrayBuffer) usize {
        return self.byte_length;
    }

    /// Clone a region of this ArrayBuffer
    ///
    /// Spec: CloneArrayBuffer(srcBuffer, srcByteOffset, srcLength, cloneConstructor)
    /// https://tc39.es/ecma262/#sec-clonearraybuffer
    pub fn clone(
        self: *const ArrayBuffer,
        allocator: std.mem.Allocator,
        src_byte_offset: usize,
        src_length: usize,
    ) !ArrayBuffer {
        // Create new buffer with the specified length
        const new_buffer = try ArrayBuffer.init(allocator, src_length);
        errdefer new_buffer.deinit(allocator);

        // Copy bytes from source to new buffer
        const src_slice = self.data[src_byte_offset..][0..src_length];
        @memcpy(new_buffer.data[0..src_length], src_slice);

        return new_buffer;
    }

    /// Transfer this ArrayBuffer (detach and return data)
    ///
    /// Spec: TransferArrayBuffer(arrayBuffer)
    /// https://tc39.es/ecma262/#sec-transferarraybuffer
    ///
    /// Note: In the spec, this creates a new ArrayBuffer with the same data
    /// and detaches the original. For our purposes, we mark as detached.
    pub fn transfer(self: *ArrayBuffer) !ArrayBuffer {
        if (self.detached) {
            return error.BufferDetached;
        }

        // Create new buffer with same data (transfer ownership)
        const transferred = ArrayBuffer{
            .data = self.data,
            .byte_length = self.byte_length,
            .detached = false,
        };

        // Mark original as detached
        self.detached = true;
        self.byte_length = 0;

        return transferred;
    }

    /// Check if buffer can be copied
    ///
    /// Spec: CanCopyDataBlockBytes(toBlock, toIndex, fromBlock, fromIndex, count)
    pub fn canCopyFrom(
        self: *const ArrayBuffer,
        to_index: usize,
        from_buffer: *const ArrayBuffer,
        from_index: usize,
        count: usize,
    ) bool {
        // Check if buffers are detached
        if (self.detached or from_buffer.detached) {
            return false;
        }

        // Check bounds
        if (to_index + count > self.byte_length) {
            return false;
        }

        if (from_index + count > from_buffer.byte_length) {
            return false;
        }

        return true;
    }
};

/// View constructor type for creating typed array views
///
/// Spec: § 4.7.4 "viewConstructor: a typed array constructor or %DataView%"
pub const ViewConstructor = enum {
    data_view,
    uint8_array,
    int8_array,
    uint16_array,
    int16_array,
    uint32_array,
    int32_array,
    float32_array,
    float64_array,
    uint8_clamped_array,
    bigint64_array,
    biguint64_array,

    /// Get the element size in bytes for this view constructor
    pub fn elementSize(self: ViewConstructor) u64 {
        return switch (self) {
            .data_view => 1,
            .uint8_array => 1,
            .int8_array => 1,
            .uint8_clamped_array => 1,
            .uint16_array => 2,
            .int16_array => 2,
            .uint32_array => 4,
            .int32_array => 4,
            .float32_array => 4,
            .float64_array => 8,
            .bigint64_array => 8,
            .biguint64_array => 8,
        };
    }
};

/// Reader type for pull-into descriptor
///
/// Spec: § 4.7.4 "readerType: 'default', 'byob', or 'none'"
pub const ReaderType = enum {
    default,
    byob,
    none,
};

/// Pull-into descriptor
///
/// Spec: § 4.7.4 "A pull-into descriptor is a struct with the following items:"
///
/// A pull-into descriptor tracks the state of a BYOB read operation,
/// including the buffer being filled and how much data has been written.
pub const PullIntoDescriptor = struct {
    /// buffer: ArrayBuffer being filled
    buffer: *ArrayBuffer,
    /// bufferByteLength: original byte length of buffer
    buffer_byte_length: u64,
    /// byteOffset: offset into buffer where data starts
    byte_offset: u64,
    /// byteLength: length of the region being filled
    byte_length: u64,
    /// bytesFilled: number of bytes written so far
    bytes_filled: u64,
    /// minimumFill: minimum bytes required before fulfilling
    minimum_fill: u64,
    /// elementSize: size of each array element in bytes
    element_size: u64,
    /// viewConstructor: constructor for creating the view
    view_constructor: ViewConstructor,
    /// readerType: type of reader making the request
    reader_type: ReaderType,

    /// Initialize a new pull-into descriptor
    pub fn init(
        buffer: *ArrayBuffer,
        buffer_byte_length: u64,
        byte_offset: u64,
        byte_length: u64,
        minimum_fill: u64,
        element_size: u64,
        view_constructor: ViewConstructor,
        reader_type: ReaderType,
    ) PullIntoDescriptor {
        return .{
            .buffer = buffer,
            .buffer_byte_length = buffer_byte_length,
            .byte_offset = byte_offset,
            .byte_length = byte_length,
            .bytes_filled = 0,
            .minimum_fill = minimum_fill,
            .element_size = element_size,
            .view_constructor = view_constructor,
            .reader_type = reader_type,
        };
    }

    /// Get remaining bytes to fill
    pub fn remainingBytes(self: *const PullIntoDescriptor) u64 {
        return self.byte_length - self.bytes_filled;
    }

    /// Check if minimum fill requirement is met
    pub fn isMinimumFillMet(self: *const PullIntoDescriptor) bool {
        return self.bytes_filled >= self.minimum_fill;
    }

    /// Check if completely filled
    pub fn isFilled(self: *const PullIntoDescriptor) bool {
        return self.bytes_filled >= self.byte_length;
    }

    /// Get element size for the view constructor
    pub fn getElementSize(constructor: ViewConstructor) u64 {
        return switch (constructor) {
            .data_view => 1,
            .uint8_array, .int8_array, .uint8_clamped_array => 1,
            .uint16_array, .int16_array => 2,
            .uint32_array, .int32_array, .float32_array => 4,
            .float64_array, .bigint64_array, .biguint64_array => 8,
        };
    }
};

// Tests





