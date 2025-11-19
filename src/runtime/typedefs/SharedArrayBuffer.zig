//! ECMAScript SharedArrayBuffer
//!
//! Spec: ECMAScript § 25.2 SharedArrayBuffer Objects
//!
//! The SharedArrayBuffer object is used to represent a generic fixed-length raw
//! binary data buffer that can be shared between agents.

const std = @import("std");

/// SharedArrayBuffer represents a fixed-length raw binary data buffer
/// that can be shared between agents (workers/threads)
///
/// Spec: ECMAScript § 25.2.2 The SharedArrayBuffer Constructor
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
};
