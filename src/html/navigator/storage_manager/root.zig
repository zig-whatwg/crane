//! Storage Manager API (Navigator Integration)
//!
//! Spec: Storage Standard
//! https://storage.spec.whatwg.org/
//!
//! This module provides the StorageManager interface for navigator.storage.
//! It wraps the storage backend's StorageManager for the document's origin.

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import the storage backend's StorageManager
const storage = @import("storage");
const BackendStorageManager = storage.StorageManager;
const standard = storage.standard;

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
    /// Security error (opaque origin)
    SecurityError,
};

/// StorageManager interface for navigator.storage
/// Spec: StorageManager interface
/// [SecureContext] required
///
/// This wraps the storage backend's full StorageManager implementation.
/// When an origin is set (via setOrigin), all operations delegate to
/// the backend. Before origin is set, operations return default values.
pub const StorageManager = struct {
    allocator: Allocator,

    /// The document origin for this storage manager
    origin: ?[]const u8,

    /// Owned copy of origin string
    origin_owned: bool,

    /// Backend storage manager (lazily created when origin is set)
    backend: ?BackendStorageManager,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .origin = null,
            .origin_owned = false,
            .backend = null,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.backend) |*backend| {
            backend.deinit();
        }
        if (self.origin_owned) {
            if (self.origin) |origin| {
                self.allocator.free(origin);
            }
        }
    }

    /// Set the origin for this StorageManager
    /// This must be called to enable storage operations for an origin.
    /// Typically called when associating with a document's origin.
    pub fn setOrigin(self: *Self, origin: []const u8) !void {
        // Clean up any existing origin
        if (self.origin_owned) {
            if (self.origin) |old_origin| {
                self.allocator.free(old_origin);
            }
        }
        if (self.backend) |*backend| {
            backend.deinit();
        }

        // Store new origin
        const origin_copy = try self.allocator.dupe(u8, origin);
        self.origin = origin_copy;
        self.origin_owned = true;

        // Create backend storage manager for this origin
        self.backend = try BackendStorageManager.init(self.allocator, origin_copy);
    }

    /// Check if storage is persisted
    /// Spec: persisted()
    /// Returns true if storage will not be evicted without user action
    pub fn getPersisted(self: *Self) !bool {
        if (self.backend) |*backend| {
            return backend.persisted();
        }
        // No origin set - return false
        return false;
    }

    /// Request persistent storage
    /// Spec: persist()
    /// Returns true if persistence was granted
    pub fn persist(self: *Self) StorageManagerError!bool {
        if (self.backend) |*backend| {
            return backend.persist() catch return false;
        }
        // No origin set - deny
        return false;
    }

    /// Get storage estimate
    /// Spec: estimate()
    pub fn estimate(self: *Self) StorageManagerError!StorageEstimate {
        if (self.backend) |*backend| {
            if (backend.estimate() catch null) |est| {
                return .{
                    .usage = est.usage,
                    .quota = est.quota,
                };
            }
        }
        // No origin set or error - return defaults
        return .{
            .usage = 0,
            .quota = 50 * 1024 * 1024, // 50 MiB default quota
        };
    }

    /// Get the origin this StorageManager is associated with
    pub fn getOrigin(self: *const Self) ?[]const u8 {
        return self.origin;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "StorageManager - init and deinit" {
    const allocator = std.testing.allocator;

    var storage_mgr = StorageManager.init(allocator);
    defer storage_mgr.deinit();

    // No origin set - not persisted
    const is_persisted = try storage_mgr.getPersisted();
    try std.testing.expect(!is_persisted);
}

test "StorageManager - persist without origin" {
    const allocator = std.testing.allocator;

    var storage_mgr = StorageManager.init(allocator);
    defer storage_mgr.deinit();

    // No origin set - denies persistence
    const result = try storage_mgr.persist();
    try std.testing.expect(!result);
}

test "StorageManager - estimate without origin" {
    const allocator = std.testing.allocator;

    var storage_mgr = StorageManager.init(allocator);
    defer storage_mgr.deinit();

    // No origin set - returns defaults
    const est = try storage_mgr.estimate();
    try std.testing.expectEqual(@as(u64, 0), est.usage);
    try std.testing.expect(est.quota > 0);
}

test "StorageManager - setOrigin enables storage" {
    const allocator = std.testing.allocator;

    // Clean up global storage shed before test
    standard.deinitGlobalStorageShed(allocator);
    defer standard.deinitGlobalStorageShed(allocator);

    var storage_mgr = StorageManager.init(allocator);
    defer storage_mgr.deinit();

    // Set origin
    try storage_mgr.setOrigin("https://example.com");

    // Now operations work with the origin
    try std.testing.expectEqualStrings("https://example.com", storage_mgr.getOrigin().?);

    // Check persisted (new origins start as not persisted)
    const is_persisted = try storage_mgr.getPersisted();
    try std.testing.expect(!is_persisted);

    // Get estimate (should have real values now)
    const est = try storage_mgr.estimate();
    try std.testing.expect(est.quota > 0);
}
