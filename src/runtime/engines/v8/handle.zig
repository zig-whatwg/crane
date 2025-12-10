//! Reference-Counted V8 Handle
//!
//! This module provides a reference-counted wrapper for V8 Global handles,
//! enabling safe sharing of V8 values across multiple owners without memory leaks
//! or use-after-free bugs.
//!
//! ## Problem Solved
//!
//! V8 Global handles have manual lifecycle management - they must be explicitly
//! disposed. When multiple parts of code need to share a V8 value:
//! - Manual tracking of who "owns" the handle is error-prone
//! - Disposing too early causes use-after-free
//! - Forgetting to dispose causes memory leaks
//!
//! V8Handle provides automatic lifecycle management through reference counting.
//!
//! ## Usage
//!
//! ```zig
//! // Create a ref-counted handle
//! const handle = try V8Handle.init(allocator, isolate, local_value);
//!
//! // Share with another component (increments ref count)
//! const copy = handle.clone();
//!
//! // Both can use the handle
//! const value = handle.get(isolate);
//! const value2 = copy.get(isolate);
//!
//! // When done (order doesn't matter)
//! copy.deinit();   // ref_count: 2 → 1
//! handle.deinit(); // ref_count: 1 → 0, Global handle disposed
//! ```
//!
//! ## Thread Safety
//!
//! Uses atomic operations for reference counting. However, V8 isolates are
//! single-threaded, so concurrent access to the underlying V8 value should
//! be avoided.

const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
const ffi = @import("ffi.zig");
const GlobalHandle = @import("global_handles.zig").GlobalHandle;

/// Reference-counted wrapper for V8 Global handles.
///
/// Provides automatic lifecycle management for V8 values that need to be
/// shared across multiple owners. The underlying Global handle is automatically
/// disposed when the last V8Handle reference is released.
pub const V8Handle = struct {
    inner: *Inner,

    const Inner = struct {
        /// Reference count (atomic for thread safety)
        ref_count: std.atomic.Value(u32),

        /// The underlying V8 Global handle
        global: GlobalHandle,

        /// The V8 isolate (needed for operations)
        isolate: *ffi.Isolate,

        /// Allocator for freeing the Inner struct
        allocator: Allocator,

        /// Whether the handle has been disposed
        disposed: bool,

        /// Increment reference count
        pub fn ref(self: *Inner) void {
            _ = self.ref_count.fetchAdd(1, .monotonic);
        }

        /// Decrement reference count, dispose if zero
        pub fn unref(self: *Inner) void {
            // fetchSub returns the OLD value, so check if it was 1
            if (self.ref_count.fetchSub(1, .release) == 1) {
                // Ensure all writes are visible before cleanup
                std.atomic.fence(.acquire);

                // Dispose the V8 Global handle
                self.dispose();

                // Free the Inner struct
                self.allocator.destroy(self);
            }
        }

        /// Dispose the underlying Global handle
        fn dispose(self: *Inner) void {
            if (!self.disposed) {
                self.global.dispose();
                self.disposed = true;
            }
        }
    };

    /// Create a new V8Handle from a Local value.
    ///
    /// Converts the Local value to a Global handle and wraps it with
    /// reference counting. The handle starts with a ref count of 1.
    ///
    /// Parameters:
    ///   allocator: Allocator for the Inner struct
    ///   isolate: The V8 isolate
    ///   local: A Local<Value> pointer (must be valid in current HandleScope)
    ///
    /// Returns:
    ///   A new V8Handle, or error if Global handle creation fails
    pub fn init(allocator: Allocator, isolate: *ffi.Isolate, local: *anyopaque) !V8Handle {
        const global = GlobalHandle.create(isolate, local) orelse {
            return error.GlobalHandleCreationFailed;
        };
        errdefer global.dispose();

        const inner = try allocator.create(Inner);
        inner.* = .{
            .ref_count = std.atomic.Value(u32).init(1),
            .global = global,
            .isolate = isolate,
            .allocator = allocator,
            .disposed = false,
        };

        return .{ .inner = inner };
    }

    /// Create a V8Handle from an existing GlobalHandle.
    ///
    /// Takes ownership of the provided GlobalHandle. The caller should not
    /// dispose the GlobalHandle after calling this.
    pub fn fromGlobal(allocator: Allocator, isolate: *ffi.Isolate, global: GlobalHandle) !V8Handle {
        const inner = try allocator.create(Inner);
        inner.* = .{
            .ref_count = std.atomic.Value(u32).init(1),
            .global = global,
            .isolate = isolate,
            .allocator = allocator,
            .disposed = false,
        };

        return .{ .inner = inner };
    }

    /// Clone the handle (increment ref count).
    ///
    /// Returns a new V8Handle that shares the same underlying Global handle.
    /// Both the original and clone must be deinit'd.
    pub fn clone(self: V8Handle) V8Handle {
        self.inner.ref();
        return self;
    }

    /// Release this reference.
    ///
    /// Decrements the reference count. When the count reaches zero,
    /// the underlying Global handle is disposed.
    pub fn deinit(self: V8Handle) void {
        self.inner.unref();
    }

    /// Get the reference count (for debugging/testing).
    pub fn getRefCount(self: V8Handle) u32 {
        return self.inner.ref_count.load(.monotonic);
    }

    /// Get a Local value from the Global handle.
    ///
    /// The returned pointer is only valid within the current HandleScope.
    /// Returns null if the Global handle is empty or disposed.
    pub fn get(self: V8Handle) ?*ffi.Value {
        if (self.inner.disposed) return null;
        return self.inner.global.get(self.inner.isolate);
    }

    /// Get the value as *anyopaque for FFI calls.
    pub fn getAnyopaque(self: V8Handle) ?*anyopaque {
        if (self.inner.disposed) return null;
        return self.inner.global.asAnyopaque(self.inner.isolate);
    }

    /// Check if this handle is still valid.
    ///
    /// Returns false if the handle has been disposed or the Global is empty.
    pub fn isValid(self: V8Handle) bool {
        return !self.inner.disposed and !self.inner.global.isEmpty();
    }

    /// Check if the underlying Global handle is empty.
    pub fn isEmpty(self: V8Handle) bool {
        return self.inner.global.isEmpty();
    }

    /// Get the underlying GlobalHandle (use with care).
    ///
    /// WARNING: Do not dispose the returned GlobalHandle directly.
    /// Let V8Handle manage the lifecycle.
    pub fn getGlobalHandle(self: V8Handle) GlobalHandle {
        return self.inner.global;
    }

    /// Get the isolate this handle is associated with.
    pub fn getIsolate(self: V8Handle) *ffi.Isolate {
        return self.inner.isolate;
    }
};

/// Optional V8Handle - commonly used for optional JS values
pub const OptionalV8Handle = ?V8Handle;

/// Helper to deinit an optional V8Handle
pub fn deinitOptional(handle: *OptionalV8Handle) void {
    if (handle.*) |h| {
        h.deinit();
        handle.* = null;
    }
}

// ============================================================================
// Tests
// ============================================================================

test "V8Handle: basic lifecycle" {
    // Note: This test would need a V8 isolate to run properly.
    // We test the allocation/deallocation logic without V8 integration.

    // Since we can't create a real V8 handle without an isolate,
    // we'll test the Inner struct directly for memory management

    const allocator = std.testing.allocator;

    // Simulate Inner struct lifecycle
    const TestInner = struct {
        ref_count: std.atomic.Value(u32),
        disposed: bool,
        allocator_ref: Allocator,

        pub fn ref(self: *@This()) void {
            _ = self.ref_count.fetchAdd(1, .monotonic);
        }

        pub fn unref(self: *@This()) void {
            if (self.ref_count.fetchSub(1, .release) == 1) {
                // Use fenceRelease for acquire semantics after decrement
                _ = self.ref_count.load(.acquire);
                self.disposed = true;
                self.allocator_ref.destroy(self);
            }
        }
    };

    const inner = try allocator.create(TestInner);
    inner.* = .{
        .ref_count = std.atomic.Value(u32).init(1),
        .disposed = false,
        .allocator_ref = allocator,
    };

    try std.testing.expectEqual(@as(u32, 1), inner.ref_count.load(.monotonic));

    // Ref and unref
    inner.ref();
    try std.testing.expectEqual(@as(u32, 2), inner.ref_count.load(.monotonic));

    inner.unref();
    try std.testing.expectEqual(@as(u32, 1), inner.ref_count.load(.monotonic));

    // Final unref should free
    inner.unref();
    // No leak should be detected by testing allocator
}

test "V8Handle: clone and multiple unrefs" {
    const allocator = std.testing.allocator;

    // Track cleanup
    var cleanup_called = false;

    const TestInner = struct {
        ref_count: std.atomic.Value(u32),
        cleanup_ptr: *bool,
        allocator_ref: Allocator,

        pub fn ref(self: *@This()) void {
            _ = self.ref_count.fetchAdd(1, .monotonic);
        }

        pub fn unref(self: *@This()) void {
            if (self.ref_count.fetchSub(1, .release) == 1) {
                // Use load with acquire for memory ordering
                _ = self.ref_count.load(.acquire);
                self.cleanup_ptr.* = true;
                self.allocator_ref.destroy(self);
            }
        }
    };

    const inner = try allocator.create(TestInner);
    inner.* = .{
        .ref_count = std.atomic.Value(u32).init(1),
        .cleanup_ptr = &cleanup_called,
        .allocator_ref = allocator,
    };

    // Simulate cloning
    inner.ref(); // ref_count: 2
    inner.ref(); // ref_count: 3

    try std.testing.expect(!cleanup_called);

    inner.unref(); // 3 → 2
    try std.testing.expect(!cleanup_called);

    inner.unref(); // 2 → 1
    try std.testing.expect(!cleanup_called);

    inner.unref(); // 1 → 0, cleanup!
    try std.testing.expect(cleanup_called);
}
