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
// WeakV8Handle - Weak Reference Support
// ============================================================================

/// Callback type for weak reference finalization
pub const WeakCallback = *const fn (user_data: ?*anyopaque) void;

/// Weak reference wrapper for V8 Global handles.
///
/// Unlike V8Handle, a WeakV8Handle does NOT prevent V8 garbage collection.
/// When the underlying V8 object has no more strong references, V8 GC can
/// collect it, and the WeakV8Handle becomes "dead" (isAlive returns false).
///
/// ## Use Cases
///
/// - Object caches: Keep references to JS objects without preventing GC
/// - Event listeners: Allow JS callbacks to be GC'd when no longer needed
/// - DOM node references: Don't keep entire DOM tree alive through JS references
///
/// ## Usage
///
/// ```zig
/// // Create a weak handle from a strong handle
/// const weak = try WeakV8Handle.init(allocator, strong_handle);
///
/// // Later, check if still alive
/// if (weak.isAlive()) {
///     // Convert back to strong for use
///     if (try weak.toStrong(allocator)) |strong| {
///         defer strong.deinit();
///         // Use the strong handle
///     }
/// }
///
/// // Cleanup
/// weak.deinit();
/// ```
///
/// ## GC Callback
///
/// You can register a callback to be notified when the value is collected:
///
/// ```zig
/// weak.setCallback(myCallback, my_user_data);
/// ```
pub const WeakV8Handle = struct {
    inner: *Inner,

    const Inner = struct {
        /// The underlying GlobalHandle (configured as weak)
        global: GlobalHandle,

        /// The V8 isolate
        isolate: *ffi.Isolate,

        /// Allocator for freeing the Inner struct
        allocator: Allocator,

        /// Whether the handle has been deinit'd
        deinited: bool,

        /// User-provided callback data (for GC notification)
        callback_data: ?*anyopaque,
    };

    /// Create a WeakV8Handle from a V8Handle.
    ///
    /// The original V8Handle is NOT consumed - you can continue using it.
    /// The weak handle is created from the same underlying V8 value.
    ///
    /// Parameters:
    ///   allocator: Allocator for the Internal struct
    ///   strong: A V8Handle to create a weak reference to
    ///
    /// Returns:
    ///   A new WeakV8Handle, or error if creation fails
    pub fn init(allocator: Allocator, strong: V8Handle) !WeakV8Handle {
        const isolate = strong.getIsolate();

        // Get the value from the strong handle's global
        const local = strong.inner.global.get(isolate) orelse {
            return error.InvalidHandle;
        };

        // Create a new weak global handle
        const weak_global = GlobalHandle.createWeak(isolate, @ptrCast(local), null, null) orelse {
            return error.WeakHandleCreationFailed;
        };
        errdefer weak_global.dispose();

        const inner = try allocator.create(Inner);
        inner.* = .{
            .global = weak_global,
            .isolate = isolate,
            .allocator = allocator,
            .deinited = false,
            .callback_data = null,
        };

        return .{ .inner = inner };
    }

    /// Create a WeakV8Handle from a local value pointer.
    ///
    /// Parameters:
    ///   allocator: Allocator for the Internal struct
    ///   isolate: The V8 isolate
    ///   local: A Local<Value> pointer
    ///
    /// Returns:
    ///   A new WeakV8Handle, or error if creation fails
    pub fn initFromLocal(allocator: Allocator, isolate: *ffi.Isolate, local: *anyopaque) !WeakV8Handle {
        const weak_global = GlobalHandle.createWeak(isolate, local, null, null) orelse {
            return error.WeakHandleCreationFailed;
        };
        errdefer weak_global.dispose();

        const inner = try allocator.create(Inner);
        inner.* = .{
            .global = weak_global,
            .isolate = isolate,
            .allocator = allocator,
            .deinited = false,
            .callback_data = null,
        };

        return .{ .inner = inner };
    }

    /// Release this weak handle.
    ///
    /// This disposes the underlying V8 weak reference and frees memory.
    /// After calling this, the WeakV8Handle should not be used.
    pub fn deinit(self: WeakV8Handle) void {
        if (!self.inner.deinited) {
            self.inner.global.dispose();
            self.inner.deinited = true;
        }
        self.inner.allocator.destroy(self.inner);
    }

    /// Check if the referenced V8 object is still alive.
    ///
    /// Returns false if:
    /// - The V8 object was garbage collected
    /// - The handle was disposed
    pub fn isAlive(self: WeakV8Handle) bool {
        if (self.inner.deinited) return false;
        return !self.inner.global.isEmpty();
    }

    /// Convert the weak reference to a strong V8Handle.
    ///
    /// Returns null if the referenced object has been garbage collected.
    /// The returned V8Handle must be deinit'd by the caller.
    ///
    /// Parameters:
    ///   allocator: Allocator for the new V8Handle
    ///
    /// Returns:
    ///   A new strong V8Handle, or null if the object is gone
    pub fn toStrong(self: WeakV8Handle, allocator: Allocator) !?V8Handle {
        if (!self.isAlive()) return null;

        // Get the local value from the weak global
        const local = self.inner.global.get(self.inner.isolate) orelse {
            return null;
        };

        // Create a new strong V8Handle from the local
        return try V8Handle.init(allocator, self.inner.isolate, @ptrCast(local));
    }

    /// Get a Local value pointer if the object is still alive.
    ///
    /// The returned pointer is only valid within the current HandleScope.
    /// Returns null if the object has been garbage collected.
    pub fn get(self: WeakV8Handle) ?*ffi.Value {
        if (!self.isAlive()) return null;
        return self.inner.global.get(self.inner.isolate);
    }

    /// Set a callback to be invoked when the V8 object is garbage collected.
    ///
    /// Note: The callback is invoked by V8 during GC, so be careful about
    /// what operations you perform in the callback. Avoid allocations and
    /// other complex operations.
    ///
    /// Parameters:
    ///   callback: Function to call when the object is collected
    ///   user_data: Data to pass to the callback
    pub fn setGCCallback(self: *WeakV8Handle, user_data: ?*anyopaque, callback: ffi.WeakCallbackFn) void {
        self.inner.callback_data = user_data;
        self.inner.global.makeWeak(user_data, callback);
    }

    /// Clear the GC callback and restore as a regular weak reference.
    pub fn clearGCCallback(self: *WeakV8Handle) void {
        self.inner.global.clearWeak();
        self.inner.callback_data = null;
    }

    /// Get the isolate this handle is associated with.
    pub fn getIsolate(self: WeakV8Handle) *ffi.Isolate {
        return self.inner.isolate;
    }
};

/// Optional WeakV8Handle
pub const OptionalWeakV8Handle = ?WeakV8Handle;

/// Helper to deinit an optional WeakV8Handle
pub fn deinitOptionalWeak(handle: *OptionalWeakV8Handle) void {
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
