//! File Locking Utilities
//!
//! Spec: https://fs.spec.whatwg.org/#file-entry-lock
//!
//! Provides higher-level locking utilities for file system operations.
//! The core lock state is stored on FileEntry, but this module provides
//! RAII-style lock guards and utilities.

const std = @import("std");
const entry_mod = @import("entry.zig");

const FileEntry = entry_mod.FileEntry;
const LockState = entry_mod.LockState;
const LockResult = entry_mod.LockResult;

/// Lock type for file operations.
pub const LockType = enum {
    /// Exclusive lock - only one holder allowed (for FileSystemSyncAccessHandle)
    exclusive,
    /// Shared lock - multiple holders allowed (for FileSystemWritableFileStream)
    shared,
};

/// RAII-style lock guard for file entries.
/// Automatically releases the lock when the guard goes out of scope.
pub const FileLockGuard = struct {
    /// The file entry being locked
    file: *FileEntry,
    /// Whether we actually hold the lock
    held: bool,

    const Self = @This();

    /// Try to acquire a lock on the file entry.
    /// Returns a guard if successful, null if the lock couldn't be acquired.
    pub fn tryAcquire(file: *FileEntry, lock_type: LockType) ?Self {
        const result = switch (lock_type) {
            .exclusive => file.takeLock(.exclusive),
            .shared => file.takeLock(.shared),
        };

        if (result == .success) {
            return .{
                .file = file,
                .held = true,
            };
        }
        return null;
    }

    /// Release the lock.
    /// Safe to call multiple times - only releases once.
    pub fn release(self: *Self) void {
        if (self.held) {
            self.file.releaseLock();
            self.held = false;
        }
    }

    /// Destructor - release the lock when guard goes out of scope.
    pub fn deinit(self: *Self) void {
        self.release();
    }
};

/// Result of a lock operation with additional context.
pub const LockOperationResult = struct {
    success: bool,
    error_message: ?[]const u8,

    pub fn ok() LockOperationResult {
        return .{ .success = true, .error_message = null };
    }

    pub fn fail(message: []const u8) LockOperationResult {
        return .{ .success = false, .error_message = message };
    }
};

/// Check if a lock can be acquired without actually acquiring it.
pub fn canAcquireLock(file: *const FileEntry, lock_type: LockType) bool {
    return switch (lock_type) {
        .exclusive => file.lock == .open,
        .shared => file.lock == .open or file.lock == .taken_shared,
    };
}

/// Get a human-readable description of the current lock state.
pub fn describeLockState(state: LockState) []const u8 {
    return switch (state) {
        .open => "not locked",
        .taken_exclusive => "exclusively locked (by sync access handle)",
        .taken_shared => "shared lock held (by writable stream)",
    };
}

// ============================================================================
// Tests
// ============================================================================

test "FileLockGuard - exclusive lock" {
    const allocator = std.testing.allocator;
    var file = try FileEntry.init(allocator, "test.txt");
    defer file.deinit();

    // Acquire exclusive lock
    var guard = FileLockGuard.tryAcquire(&file, .exclusive).?;
    defer guard.deinit();

    try std.testing.expect(file.isLocked());
    try std.testing.expectEqual(LockState.taken_exclusive, file.lock);

    // Can't acquire another exclusive lock
    try std.testing.expect(FileLockGuard.tryAcquire(&file, .exclusive) == null);

    // Can't acquire shared lock either
    try std.testing.expect(FileLockGuard.tryAcquire(&file, .shared) == null);
}

test "FileLockGuard - shared lock" {
    const allocator = std.testing.allocator;
    var file = try FileEntry.init(allocator, "test.txt");
    defer file.deinit();

    // Acquire shared lock
    var guard1 = FileLockGuard.tryAcquire(&file, .shared).?;
    defer guard1.deinit();

    try std.testing.expect(file.isLocked());
    try std.testing.expectEqual(LockState.taken_shared, file.lock);

    // Can acquire another shared lock
    var guard2 = FileLockGuard.tryAcquire(&file, .shared).?;
    defer guard2.deinit();

    try std.testing.expectEqual(@as(usize, 2), file.shared_lock_count);

    // Can't acquire exclusive lock
    try std.testing.expect(FileLockGuard.tryAcquire(&file, .exclusive) == null);
}

test "FileLockGuard - automatic release" {
    const allocator = std.testing.allocator;
    var file = try FileEntry.init(allocator, "test.txt");
    defer file.deinit();

    {
        var guard = FileLockGuard.tryAcquire(&file, .exclusive).?;
        defer guard.deinit();
        try std.testing.expect(file.isLocked());
    }

    // Lock should be released after guard goes out of scope
    try std.testing.expect(!file.isLocked());
}

test "FileLockGuard - manual release" {
    const allocator = std.testing.allocator;
    var file = try FileEntry.init(allocator, "test.txt");
    defer file.deinit();

    var guard = FileLockGuard.tryAcquire(&file, .exclusive).?;
    try std.testing.expect(file.isLocked());

    guard.release();
    try std.testing.expect(!file.isLocked());

    // Multiple releases are safe
    guard.release();
    try std.testing.expect(!file.isLocked());

    guard.deinit(); // Should be no-op
}

test "canAcquireLock" {
    const allocator = std.testing.allocator;
    var file = try FileEntry.init(allocator, "test.txt");
    defer file.deinit();

    // Initially can acquire any lock
    try std.testing.expect(canAcquireLock(&file, .exclusive));
    try std.testing.expect(canAcquireLock(&file, .shared));

    // Take shared lock
    _ = file.takeLock(.shared);

    // Can still acquire shared, but not exclusive
    try std.testing.expect(!canAcquireLock(&file, .exclusive));
    try std.testing.expect(canAcquireLock(&file, .shared));

    // Release and take exclusive
    file.releaseLock();
    _ = file.takeLock(.exclusive);

    // Can't acquire anything
    try std.testing.expect(!canAcquireLock(&file, .exclusive));
    try std.testing.expect(!canAcquireLock(&file, .shared));
}

test "describeLockState" {
    try std.testing.expectEqualStrings("not locked", describeLockState(.open));
    try std.testing.expectEqualStrings("exclusively locked (by sync access handle)", describeLockState(.taken_exclusive));
    try std.testing.expectEqualStrings("shared lock held (by writable stream)", describeLockState(.taken_shared));
}
