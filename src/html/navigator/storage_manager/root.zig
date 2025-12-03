//! Storage Manager API
//!
//! Spec: Storage Standard
//! https://storage.spec.whatwg.org/
//!
//! This module implements the StorageManager interface which provides
//! quota and persistence information for storage.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Storage estimate
pub const StorageEstimate = struct {
    /// Amount of storage currently used (bytes)
    usage: u64,

    /// Total quota available (bytes)
    quota: u64,
};

/// Error types for StorageManager operations
pub const StorageManagerError = error{
    /// User denied permission
    NotAllowedError,
    /// Storage not available
    QuotaExceededError,
    /// Out of memory
    OutOfMemory,
};

/// StorageManager interface implementation
/// Spec: StorageManager interface
/// [SecureContext] required
pub const StorageManager = struct {
    allocator: Allocator,

    /// Whether storage is persisted
    persisted: bool,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .persisted = false,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Check if storage is persisted
    /// Spec: persisted()
    /// Returns true if storage will not be evicted without user action
    pub fn getPersisted(self: *Self) bool {
        return self.persisted;
    }

    /// Request persistent storage
    /// Spec: persist()
    /// Returns true if persistence was granted
    pub fn persist(self: *Self) StorageManagerError!bool {
        // Stub: always deny persistence request
        _ = self;
        return false;
    }

    /// Get storage estimate
    /// Spec: estimate()
    pub fn estimate(self: *Self) StorageManagerError!StorageEstimate {
        _ = self;
        // Stub: return reasonable defaults
        return .{
            .usage = 0,
            .quota = 1024 * 1024 * 1024, // 1GB default quota
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "StorageManager - init and deinit" {
    const allocator = std.testing.allocator;

    var storage = StorageManager.init(allocator);
    defer storage.deinit();

    // Default: not persisted
    try std.testing.expect(!storage.getPersisted());
}

test "StorageManager - persist" {
    const allocator = std.testing.allocator;

    var storage = StorageManager.init(allocator);
    defer storage.deinit();

    // Stub denies persistence
    const result = try storage.persist();
    try std.testing.expect(!result);
}

test "StorageManager - estimate" {
    const allocator = std.testing.allocator;

    var storage = StorageManager.init(allocator);
    defer storage.deinit();

    const est = try storage.estimate();
    try std.testing.expectEqual(@as(u64, 0), est.usage);
    try std.testing.expect(est.quota > 0);
}
