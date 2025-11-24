//! ECMAScript ArrayBuffer with V8 Integration
//!
//! Spec: ECMAScript § 25.1 ArrayBuffer Objects
//!
//! The ArrayBuffer object is used to represent a generic raw binary data buffer.
//! This implementation supports both Zig-managed memory (for testing) and
//! V8-backed ArrayBuffers (for runtime integration).

const std = @import("std");

// V8 integration (optional - will be null if V8 not available)
const v8 = if (@hasDecl(@import("root"), "runtime"))
    @import("runtime").engines.v8.ffi
else
    null;

/// ArrayBuffer storage backend
const Storage = union(enum) {
    /// Zig-managed memory (for testing, standalone use)
    zig: struct {
        data: []u8,
        allocator: std.mem.Allocator,
    },

    /// V8-backed ArrayBuffer (for runtime integration)
    v8: if (v8 != null) *v8.?.ArrayBuffer else void,
};

/// ArrayBuffer represents a fixed-length raw binary data buffer
///
/// Spec: ECMAScript § 25.1.2 The ArrayBuffer Constructor
pub const ArrayBuffer = struct {
    storage: Storage,
    detached: bool,

    /// Create a Zig-managed ArrayBuffer (for testing)
    pub fn init(allocator: std.mem.Allocator, size: usize) !ArrayBuffer {
        const data = try allocator.alloc(u8, size);
        return ArrayBuffer{
            .storage = .{ .zig = .{ .data = data, .allocator = allocator } },
            .detached = false,
        };
    }

    /// Create a V8-backed ArrayBuffer (for runtime)
    pub fn initV8(isolate: anytype, size: usize) !ArrayBuffer {
        if (v8 == null) return error.V8NotAvailable;

        const buffer = v8.?.v8_ArrayBuffer_New(isolate, size) orelse
            return error.ArrayBufferCreationFailed;

        return ArrayBuffer{
            .storage = .{ .v8 = buffer },
            .detached = false,
        };
    }

    pub fn deinit(self: *ArrayBuffer) void {
        switch (self.storage) {
            .zig => |zig_storage| {
                zig_storage.allocator.free(zig_storage.data);
            },
            .v8 => |v8_buffer| {
                if (v8 != null) {
                    v8.?.v8_ArrayBuffer_Dispose(v8_buffer);
                }
            },
        }
    }

    /// Detach the ArrayBuffer (transfer ownership or neuter)
    ///
    /// Spec: ECMAScript § 25.1.3.2 DetachArrayBuffer
    pub fn detach(self: *ArrayBuffer) void {
        switch (self.storage) {
            .zig => |zig_storage| {
                zig_storage.allocator.free(zig_storage.data);
                self.storage = .{ .zig = .{
                    .data = &[_]u8{},
                    .allocator = zig_storage.allocator,
                } };
            },
            .v8 => |v8_buffer| {
                if (v8 != null) {
                    v8.?.v8_ArrayBuffer_Detach(v8_buffer);
                }
            },
        }
        self.detached = true;
    }

    /// Check if the ArrayBuffer is detached
    ///
    /// Spec: ECMAScript § 25.1.5.3 IsDetachedBuffer
    pub fn isDetached(self: ArrayBuffer) bool {
        switch (self.storage) {
            .zig => return self.detached,
            .v8 => |v8_buffer| {
                if (v8 != null) {
                    return v8.?.v8_ArrayBuffer_IsDetached(v8_buffer);
                }
                return self.detached;
            },
        }
    }

    /// Get the byte length of the ArrayBuffer
    ///
    /// Spec: ECMAScript § 25.1.5.1 get ArrayBuffer.prototype.byteLength
    pub fn byteLength(self: ArrayBuffer) usize {
        if (self.isDetached()) return 0;

        switch (self.storage) {
            .zig => |zig_storage| return zig_storage.data.len,
            .v8 => |v8_buffer| {
                if (v8 != null) {
                    return v8.?.v8_ArrayBuffer_ByteLength(v8_buffer);
                }
                return 0;
            },
        }
    }

    /// Get access to the backing store
    ///
    /// Returns a slice pointing to the ArrayBuffer's memory.
    /// For V8 buffers, this is the backing store pointer.
    /// For Zig buffers, this is the allocated memory.
    ///
    /// Returns null if the buffer is detached.
    pub fn getData(self: *ArrayBuffer) ?[]u8 {
        if (self.isDetached()) return null;

        switch (self.storage) {
            .zig => |zig_storage| return zig_storage.data,
            .v8 => |v8_buffer| {
                if (v8 != null) {
                    const ptr = v8.?.v8_ArrayBuffer_Data(v8_buffer) orelse return null;
                    const len = v8.?.v8_ArrayBuffer_ByteLength(v8_buffer);
                    return @as([*]u8, @ptrCast(@alignCast(ptr)))[0..len];
                }
                return null;
            },
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "ArrayBuffer - Zig-managed creation" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit();

    try testing.expectEqual(@as(usize, 1024), buffer.byteLength());
    try testing.expect(!buffer.isDetached());
}

test "ArrayBuffer - Zig-managed detach" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit();

    buffer.detach();

    try testing.expect(buffer.isDetached());
    try testing.expectEqual(@as(usize, 0), buffer.byteLength());
}

test "ArrayBuffer - Zig-managed getData" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit();

    const data = buffer.getData() orelse return error.GetDataFailed;
    try testing.expectEqual(@as(usize, 1024), data.len);

    // Write and verify
    data[0] = 42;
    data[1023] = 99;
    try testing.expectEqual(@as(u8, 42), data[0]);
    try testing.expectEqual(@as(u8, 99), data[1023]);
}

test "ArrayBuffer - V8-backed" {
    // Skip until V8 runtime is available
    if (true) return error.SkipZigTest;

    // TODO: When V8 is available:
    // 1. Create V8 isolate
    // 2. Create ArrayBuffer with initV8
    // 3. Verify byteLength
    // 4. Test getData
    // 5. Test detach
}
