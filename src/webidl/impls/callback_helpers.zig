//! Callback Disposal Helpers for WebIDL Impl Files
//!
//! This module provides utilities for proper callback lifecycle management in impl files,
//! reducing boilerplate and ensuring consistent disposal patterns.
//!
//! ## Problem Solved
//!
//! Impl files often store callbacks as `?*const anyopaque` or similar patterns without
//! proper lifecycle management. This leads to:
//! - Memory leaks when callbacks are replaced without disposing the old one
//! - Memory leaks when impl instances are destroyed without callback cleanup
//! - Double-free bugs when callbacks are copied without proper ownership
//!
//! ## Solution
//!
//! These helpers provide:
//! - `ManagedCallback`: Single optional callback with proper set/clear lifecycle
//! - `CallbackList`: List of callbacks with add/remove/clear operations
//!
//! Both use reference counting internally to support safe sharing.
//!
//! ## Usage
//!
//! ```zig
//! const Internal = struct {
//!     start_callback: ManagedCallback,
//!     event_listeners: CallbackList,
//!
//!     pub fn init(allocator: Allocator) Internal {
//!         return .{
//!             .start_callback = ManagedCallback.init(),
//!             .event_listeners = CallbackList.init(allocator),
//!         };
//!     }
//!
//!     pub fn deinit(self: *Internal) void {
//!         self.start_callback.deinit();
//!         self.event_listeners.deinit();
//!     }
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// A managed callback that handles lifecycle automatically.
///
/// Use this when you have a single optional callback (e.g., stream start/write/close callbacks).
/// The callback is stored with reference counting for safe sharing.
pub const ManagedCallback = struct {
    /// The underlying reference-counted handle
    handle: ?*Handle = null,

    const Handle = struct {
        ref_count: std.atomic.Value(u32),
        ptr: *anyopaque,
        dispose_fn: ?*const fn (*anyopaque) void,
        allocator: Allocator,
        disposed: bool,

        fn ref(self: *Handle) void {
            _ = self.ref_count.fetchAdd(1, .monotonic);
        }

        fn unref(self: *Handle) void {
            if (self.ref_count.fetchSub(1, .release) == 1) {
                std.atomic.fence(.acquire);
                self.dispose();
                self.allocator.destroy(self);
            }
        }

        fn dispose(self: *Handle) void {
            if (!self.disposed) {
                if (self.dispose_fn) |dispose_fn| {
                    dispose_fn(self.ptr);
                }
                self.disposed = true;
            }
        }
    };

    /// Create an empty managed callback.
    pub fn init() ManagedCallback {
        return .{ .handle = null };
    }

    /// Deinitialize and release any held callback.
    pub fn deinit(self: *ManagedCallback) void {
        self.clear();
    }

    /// Set the callback, disposing any previously held callback.
    ///
    /// Parameters:
    ///   allocator: Allocator for the internal handle
    ///   callback_ptr: The callback pointer to store
    ///   dispose_fn: Function to call when the callback should be disposed (can be null)
    pub fn set(
        self: *ManagedCallback,
        allocator: Allocator,
        callback_ptr: *anyopaque,
        dispose_fn: ?*const fn (*anyopaque) void,
    ) !void {
        // Clear old callback first
        self.clear();

        // Create new handle
        const handle = try allocator.create(Handle);
        handle.* = .{
            .ref_count = std.atomic.Value(u32).init(1),
            .ptr = callback_ptr,
            .dispose_fn = dispose_fn,
            .allocator = allocator,
            .disposed = false,
        };
        self.handle = handle;
    }

    /// Clear the callback, disposing it if it's the last reference.
    pub fn clear(self: *ManagedCallback) void {
        if (self.handle) |h| {
            h.unref();
            self.handle = null;
        }
    }

    /// Check if a callback is set.
    pub fn isSet(self: *const ManagedCallback) bool {
        return self.handle != null;
    }

    /// Get the callback pointer (if set and not disposed).
    pub fn get(self: *const ManagedCallback) ?*anyopaque {
        if (self.handle) |h| {
            if (!h.disposed) {
                return h.ptr;
            }
        }
        return null;
    }

    /// Clone the callback (increment reference count).
    /// The returned callback shares ownership with the original.
    pub fn clone(self: ManagedCallback) ManagedCallback {
        if (self.handle) |h| {
            h.ref();
        }
        return self;
    }
};

/// A list of managed callbacks with automatic lifecycle management.
///
/// Use this when you need to store multiple callbacks (e.g., event listeners).
pub const CallbackList = struct {
    allocator: Allocator,
    items: std.ArrayList(Entry),

    const Entry = struct {
        ptr: *anyopaque,
        dispose_fn: ?*const fn (*anyopaque) void,
    };

    /// Create an empty callback list.
    pub fn init(allocator: Allocator) CallbackList {
        return .{
            .allocator = allocator,
            .items = std.ArrayList(Entry).init(allocator),
        };
    }

    /// Deinitialize the list and dispose all callbacks.
    pub fn deinit(self: *CallbackList) void {
        for (self.items.items) |entry| {
            if (entry.dispose_fn) |dispose_fn| {
                dispose_fn(entry.ptr);
            }
        }
        self.items.deinit();
    }

    /// Add a callback to the list.
    ///
    /// Returns the index of the added callback (for later removal).
    pub fn add(
        self: *CallbackList,
        callback_ptr: *anyopaque,
        dispose_fn: ?*const fn (*anyopaque) void,
    ) !usize {
        const index = self.items.items.len;
        try self.items.append(.{
            .ptr = callback_ptr,
            .dispose_fn = dispose_fn,
        });
        return index;
    }

    /// Remove a callback by index and dispose it.
    pub fn remove(self: *CallbackList, index: usize) void {
        if (index < self.items.items.len) {
            const entry = self.items.items[index];
            if (entry.dispose_fn) |dispose_fn| {
                dispose_fn(entry.ptr);
            }
            _ = self.items.orderedRemove(index);
        }
    }

    /// Clear all callbacks and dispose them.
    pub fn clear(self: *CallbackList) void {
        for (self.items.items) |entry| {
            if (entry.dispose_fn) |dispose_fn| {
                dispose_fn(entry.ptr);
            }
        }
        self.items.clearRetainingCapacity();
    }

    /// Get the number of callbacks.
    pub fn count(self: *const CallbackList) usize {
        return self.items.items.len;
    }

    /// Get callback at index (without disposing).
    pub fn get(self: *const CallbackList, index: usize) ?*anyopaque {
        if (index < self.items.items.len) {
            return self.items.items[index].ptr;
        }
        return null;
    }

    /// Iterate over all callback pointers.
    pub fn iterate(self: *const CallbackList) []const Entry {
        return self.items.items;
    }
};

/// Helper to create a disposal function from a typed function.
///
/// Usage:
/// ```zig
/// const dispose_fn = makeDisposeFn(MyCallbackType, myCleanupFunction);
/// ```
pub fn makeDisposeFn(
    comptime T: type,
    comptime cleanup: fn (*T) void,
) *const fn (*anyopaque) void {
    const wrapper = struct {
        fn dispose(ptr: *anyopaque) void {
            const typed: *T = @ptrCast(@alignCast(ptr));
            cleanup(typed);
        }
    };
    return wrapper.dispose;
}

// ============================================================================
// Tests
// ============================================================================

test "ManagedCallback: basic lifecycle" {
    const allocator = std.testing.allocator;

    var cleanup_called = false;

    const TestContext = struct {
        flag: *bool,
    };

    const ctx = try allocator.create(TestContext);
    ctx.* = .{ .flag = &cleanup_called };

    const cleanup = struct {
        fn dispose(ptr: *anyopaque) void {
            const tc: *TestContext = @ptrCast(@alignCast(ptr));
            tc.flag.* = true;
            std.testing.allocator.destroy(tc);
        }
    }.dispose;

    var callback = ManagedCallback.init();
    defer callback.deinit();

    try callback.set(allocator, ctx, cleanup);
    try std.testing.expect(callback.isSet());
    try std.testing.expect(!cleanup_called);

    callback.clear();
    try std.testing.expect(!callback.isSet());
    try std.testing.expect(cleanup_called);
}

test "ManagedCallback: replace disposes old" {
    const allocator = std.testing.allocator;

    var first_disposed = false;
    var second_disposed = false;

    const TestContext = struct {
        flag: *bool,
    };

    const ctx1 = try allocator.create(TestContext);
    ctx1.* = .{ .flag = &first_disposed };

    const ctx2 = try allocator.create(TestContext);
    ctx2.* = .{ .flag = &second_disposed };

    const cleanup = struct {
        fn dispose(ptr: *anyopaque) void {
            const tc: *TestContext = @ptrCast(@alignCast(ptr));
            tc.flag.* = true;
            std.testing.allocator.destroy(tc);
        }
    }.dispose;

    var callback = ManagedCallback.init();
    defer callback.deinit();

    try callback.set(allocator, ctx1, cleanup);
    try std.testing.expect(!first_disposed);

    // Setting a new callback should dispose the first
    try callback.set(allocator, ctx2, cleanup);
    try std.testing.expect(first_disposed);
    try std.testing.expect(!second_disposed);
}

test "ManagedCallback: clone shares ownership" {
    const allocator = std.testing.allocator;

    var cleanup_called = false;

    const TestContext = struct {
        flag: *bool,
    };

    const ctx = try allocator.create(TestContext);
    ctx.* = .{ .flag = &cleanup_called };

    const cleanup = struct {
        fn dispose(ptr: *anyopaque) void {
            const tc: *TestContext = @ptrCast(@alignCast(ptr));
            tc.flag.* = true;
            std.testing.allocator.destroy(tc);
        }
    }.dispose;

    var callback1 = ManagedCallback.init();
    try callback1.set(allocator, ctx, cleanup);

    var callback2 = callback1.clone();

    // Clear first - should not dispose (ref count is 2)
    callback1.clear();
    try std.testing.expect(!cleanup_called);

    // Clear second - should dispose (ref count reaches 0)
    callback2.clear();
    try std.testing.expect(cleanup_called);
}

test "CallbackList: add and remove" {
    const allocator = std.testing.allocator;

    var disposed_count: u32 = 0;

    const TestContext = struct {
        count: *u32,
    };

    const cleanup = struct {
        fn dispose(ptr: *anyopaque) void {
            const tc: *TestContext = @ptrCast(@alignCast(ptr));
            tc.count.* += 1;
            std.testing.allocator.destroy(tc);
        }
    }.dispose;

    var list = CallbackList.init(allocator);
    defer list.deinit();

    const ctx1 = try allocator.create(TestContext);
    ctx1.* = .{ .count = &disposed_count };

    const ctx2 = try allocator.create(TestContext);
    ctx2.* = .{ .count = &disposed_count };

    const idx1 = try list.add(ctx1, cleanup);
    const idx2 = try list.add(ctx2, cleanup);

    try std.testing.expectEqual(@as(usize, 2), list.count());
    try std.testing.expectEqual(@as(u32, 0), disposed_count);

    _ = idx2;
    list.remove(idx1);
    try std.testing.expectEqual(@as(usize, 1), list.count());
    try std.testing.expectEqual(@as(u32, 1), disposed_count);
}

test "CallbackList: clear disposes all" {
    const allocator = std.testing.allocator;

    var disposed_count: u32 = 0;

    const TestContext = struct {
        count: *u32,
    };

    const cleanup = struct {
        fn dispose(ptr: *anyopaque) void {
            const tc: *TestContext = @ptrCast(@alignCast(ptr));
            tc.count.* += 1;
            std.testing.allocator.destroy(tc);
        }
    }.dispose;

    var list = CallbackList.init(allocator);

    for (0..5) |_| {
        const ctx = try allocator.create(TestContext);
        ctx.* = .{ .count = &disposed_count };
        _ = try list.add(ctx, cleanup);
    }

    try std.testing.expectEqual(@as(usize, 5), list.count());

    list.clear();
    try std.testing.expectEqual(@as(usize, 0), list.count());
    try std.testing.expectEqual(@as(u32, 5), disposed_count);

    list.deinit();
}
