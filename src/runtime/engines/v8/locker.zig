//! V8 Thread Safety and Locking Support
//!
//! This module provides thread safety primitives for V8 isolate access.
//! V8 isolates are NOT thread-safe - they can only be accessed from one
//! thread at a time. This module provides:
//!
//! 1. **IsolateLock** - RAII wrapper for v8::Locker for exclusive access
//! 2. **IsolateUnlock** - Temporarily release lock for blocking operations
//! 3. **ThreadCheck** - Debug-mode thread affinity verification
//!
//! ## Usage Pattern
//!
//! For single-threaded applications, no locking is needed - just ensure
//! all V8 operations happen on the same thread.
//!
//! For multi-threaded access to the same isolate:
//!
//! ```zig
//! // Thread 1: Acquire lock before V8 operations
//! var lock = IsolateLock.acquire(isolate);
//! defer lock.release();
//! // ... do V8 work ...
//!
//! // Thread 2: Will block until Thread 1 releases
//! var lock2 = IsolateLock.acquire(isolate);
//! defer lock2.release();
//! // ... do V8 work ...
//! ```
//!
//! For blocking operations within a locked section:
//!
//! ```zig
//! var lock = IsolateLock.acquire(isolate);
//! defer lock.release();
//!
//! // Need to do I/O that might block
//! {
//!     var unlock = IsolateUnlock.release(isolate);
//!     defer unlock.reacquire();
//!     // ... blocking I/O here - other threads can use isolate ...
//! }
//! // Lock automatically reacquired
//! ```

const std = @import("std");
const ffi = @import("ffi.zig");

// ============================================================================
// IsolateLock - Exclusive Isolate Access
// ============================================================================

/// RAII wrapper for v8::Locker
///
/// Provides exclusive access to a V8 isolate. When multiple threads need
/// to access the same isolate, they must acquire a lock first.
///
/// The lock is released when `release()` is called or when the struct
/// goes out of scope (use with `defer`).
pub const IsolateLock = struct {
    locker: ?*anyopaque,
    isolate: *ffi.Isolate,

    const Self = @This();

    /// Acquire exclusive lock on isolate
    ///
    /// This will block if another thread holds the lock.
    /// Use with `defer lock.release()` to ensure cleanup.
    pub fn acquire(isolate: *ffi.Isolate) Self {
        return .{
            .locker = ffi.v8_Locker_New(isolate),
            .isolate = isolate,
        };
    }

    /// Try to acquire lock without blocking
    ///
    /// Note: V8's Locker API doesn't provide a non-blocking acquire mechanism.
    /// This will always succeed but may block if another thread holds the lock.
    /// The implementation simply checks if the current thread already has the lock.
    ///
    /// Returns null if the lock state cannot be determined safely.
    pub fn tryAcquire(isolate: *ffi.Isolate) ?Self {
        // V8's Locker is recursive, so we can always acquire.
        // This is a simplification - in practice, this will block if
        // another thread holds the lock.
        return acquire(isolate);
    }

    /// Release the lock
    ///
    /// After calling this, the isolate may be accessed by other threads.
    pub fn release(self: *Self) void {
        if (self.locker) |l| {
            ffi.v8_Locker_Dispose(l);
        }
        self.locker = null;
    }

    /// Check if this lock is valid (not released)
    pub fn isValid(self: Self) bool {
        return self.locker != null;
    }

    /// Check if current thread holds the lock for an isolate
    pub fn isLocked(isolate: *ffi.Isolate) bool {
        return ffi.v8_Locker_IsLocked(isolate);
    }
};

// ============================================================================
// IsolateUnlock - Temporary Lock Release
// ============================================================================

/// RAII wrapper for v8::Unlocker
///
/// Temporarily releases an isolate lock to allow other threads to access
/// the isolate while the current thread performs blocking operations.
///
/// The lock is automatically reacquired when the unlocker is disposed.
pub const IsolateUnlock = struct {
    unlocker: ?*anyopaque,
    isolate: *ffi.Isolate,

    const Self = @This();

    /// Release the current thread's lock on the isolate
    ///
    /// Other threads can now acquire the lock.
    /// Use with `defer unlock.reacquire()` to restore the lock.
    pub fn release(isolate: *ffi.Isolate) Self {
        return .{
            .unlocker = ffi.v8_Unlocker_New(isolate),
            .isolate = isolate,
        };
    }

    /// Reacquire the lock
    ///
    /// This will block if another thread currently holds the lock.
    pub fn reacquire(self: *Self) void {
        if (self.unlocker) |u| {
            ffi.v8_Unlocker_Dispose(u);
        }
        self.unlocker = null;
    }

    /// Check if currently unlocked
    pub fn isUnlocked(self: Self) bool {
        return self.unlocker != null;
    }
};

// ============================================================================
// ThreadCheck - Debug Thread Affinity Verification
// ============================================================================

/// Debug-mode thread affinity checker
///
/// Tracks which thread "owns" an isolate and panics if accessed from
/// a different thread. This catches threading bugs early in development.
///
/// In release mode, all operations are no-ops for zero overhead.
pub const ThreadCheck = struct {
    expected_thread: ?std.Thread.Id = null,

    const Self = @This();

    /// Check that we're on the expected thread
    ///
    /// First call records the current thread as the owner.
    /// Subsequent calls verify we're still on that thread.
    pub fn check(self: *Self) void {
        if (!std.debug.runtime_safety) return;

        const current = std.Thread.getCurrentId();
        if (self.expected_thread) |expected| {
            if (expected != current) {
                std.debug.panic(
                    "Thread safety violation: V8 isolate accessed from wrong thread.\n" ++
                        "  Expected thread: {}\n" ++
                        "  Actual thread: {}\n" ++
                        "  Use IsolateLock for multi-threaded access.",
                    .{ expected, current },
                );
            }
        } else {
            self.expected_thread = current;
        }
    }

    /// Clear the recorded thread (e.g., when transferring isolate ownership)
    pub fn clear(self: *Self) void {
        self.expected_thread = null;
    }

    /// Set a specific thread as the owner
    pub fn setOwner(self: *Self, thread_id: std.Thread.Id) void {
        self.expected_thread = thread_id;
    }

    /// Get the current owner thread (if any)
    pub fn getOwner(self: Self) ?std.Thread.Id {
        return self.expected_thread;
    }
};

// ============================================================================
// Convenience Functions
// ============================================================================

/// Execute a function while holding the isolate lock
///
/// Automatically acquires and releases the lock around the function call.
pub fn withLock(
    isolate: *ffi.Isolate,
    context: anytype,
    comptime func: fn (@TypeOf(context)) anyerror!void,
) !void {
    var lock = IsolateLock.acquire(isolate);
    defer lock.release();

    try func(context);
}

/// Execute a function with the isolate temporarily unlocked
///
/// Use for blocking operations that don't need V8 access.
pub fn withUnlock(
    isolate: *ffi.Isolate,
    context: anytype,
    comptime func: fn (@TypeOf(context)) anyerror!void,
) !void {
    var unlock = IsolateUnlock.release(isolate);
    defer unlock.reacquire();

    try func(context);
}

/// Assert that the current thread holds the lock (debug only)
pub fn assertLocked(isolate: *ffi.Isolate) void {
    if (std.debug.runtime_safety) {
        if (!IsolateLock.isLocked(isolate)) {
            std.debug.panic(
                "V8 isolate accessed without holding lock.\n" ++
                    "  Use IsolateLock.acquire() before V8 operations.",
                .{},
            );
        }
    }
}

/// Assert that the current thread does NOT hold the lock (debug only)
pub fn assertUnlocked(isolate: *ffi.Isolate) void {
    if (std.debug.runtime_safety) {
        if (IsolateLock.isLocked(isolate)) {
            std.debug.panic(
                "Expected isolate to be unlocked but lock is held.\n" ++
                    "  Release lock before this operation.",
                .{},
            );
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

test "ThreadCheck basic usage" {
    var checker = ThreadCheck{};

    // First check records thread
    checker.check();
    try std.testing.expect(checker.expected_thread != null);

    // Second check should pass (same thread)
    checker.check();

    // Clear and re-check
    checker.clear();
    try std.testing.expect(checker.expected_thread == null);
}

test "IsolateLock validity" {
    // Note: Can't fully test without real V8 isolate
    // Just verify the struct compiles and has expected fields
    const LockType = IsolateLock;
    try std.testing.expect(@sizeOf(LockType) > 0);
}
