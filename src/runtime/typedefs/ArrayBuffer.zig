//! ECMAScript ArrayBuffer
//!
//! Spec: ECMAScript § 25.1 ArrayBuffer Objects
//!
//! The ArrayBuffer object is used to represent a generic raw binary data buffer.

const std = @import("std");

/// ArrayBuffer represents a fixed-length raw binary data buffer
///
/// Spec: ECMAScript § 25.1.2 The ArrayBuffer Constructor
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

    /// Detach the ArrayBuffer (transfer ownership or neuter)
    ///
    /// Spec: ECMAScript § 25.1.3.2 DetachArrayBuffer
    pub fn detach(self: *ArrayBuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
        self.data = &[_]u8{};
        self.detached = true;
    }

    /// Check if the ArrayBuffer is detached
    ///
    /// Spec: ECMAScript § 25.1.5.3 IsDetachedBuffer
    pub fn isDetached(self: ArrayBuffer) bool {
        return self.detached;
    }

    /// Get the byte length of the ArrayBuffer
    ///
    /// Spec: ECMAScript § 25.1.5.1 get ArrayBuffer.prototype.byteLength
    pub fn byteLength(self: ArrayBuffer) usize {
        if (self.detached) return 0;
        return self.data.len;
    }
};
