//! StorageManager Interface Implementation
//!
//! Implements the WHATWG Storage Standard StorageManager interface.
//! https://storage.spec.whatwg.org/#storagemanager
//!
//! The StorageManager interface provides methods for:
//! - Querying persistence status (`persisted()`)
//! - Requesting persistent storage (`persist()`)
//! - Estimating storage usage and quota (`estimate()`)
//!
//! ## Usage
//!
//! ```zig
//! const manager = StorageManager.init(allocator, "https://example.com");
//! defer manager.deinit();
//!
//! // Check if storage is persisted
//! const is_persisted = try manager.persisted();
//!
//! // Request persistent storage (requires user permission)
//! const granted = try manager.persist();
//!
//! // Get storage estimate
//! if (try manager.estimate()) |est| {
//!     std.debug.print("Usage: {} bytes, Quota: {} bytes\n", .{ est.usage, est.quota });
//! }
//! ```

const std = @import("std");
const standard = @import("standard.zig");

/// StorageManager interface
/// https://storage.spec.whatwg.org/#storagemanager
pub const StorageManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    /// The origin this StorageManager is associated with
    origin: []const u8,
    /// Owned copy of origin string
    origin_owned: bool,

    /// Permission request callback type
    /// Returns true if user grants persistent storage permission
    pub const PermissionCallback = *const fn (origin: []const u8) bool;

    /// Default permission callback (always denies)
    fn defaultPermissionCallback(_: []const u8) bool {
        return false;
    }

    /// Callback for requesting persistent storage permission
    /// This should be set by the embedder to show a permission prompt
    var permission_callback: PermissionCallback = defaultPermissionCallback;

    /// Set the permission callback for persist() requests
    /// The embedder should set this to integrate with their permission system
    pub fn setPermissionCallback(callback: PermissionCallback) void {
        permission_callback = callback;
    }

    /// Initialize a StorageManager for the given origin
    pub fn init(allocator: std.mem.Allocator, origin: []const u8) !Self {
        const origin_copy = try allocator.dupe(u8, origin);
        return Self{
            .allocator = allocator,
            .origin = origin_copy,
            .origin_owned = true,
        };
    }

    /// Initialize with a borrowed origin (caller maintains ownership)
    pub fn initBorrowed(allocator: std.mem.Allocator, origin: []const u8) Self {
        return Self{
            .allocator = allocator,
            .origin = origin,
            .origin_owned = false,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        if (self.origin_owned) {
            self.allocator.free(self.origin);
        }
    }

    /// Check if storage for this origin is persisted
    /// https://storage.spec.whatwg.org/#dom-storagemanager-persisted
    ///
    /// Returns a boolean indicating whether the origin's storage bucket
    /// is in "persistent" mode (protected from automatic eviction).
    ///
    /// Algorithm:
    /// 1. Let shelf be the result of obtaining a local storage shelf for origin
    /// 2. If shelf is failure, return false
    /// 3. Let bucket be shelf's bucket map["default"]
    /// 4. Return bucket's mode is "persistent"
    pub fn persisted(self: *Self) !bool {
        // Step 1: Obtain the local storage shelf for this origin
        const shelf = try standard.obtainLocalStorageShelf(
            self.allocator,
            self.origin,
        ) orelse return false;

        // Step 2-3: Get the default bucket
        const bucket = shelf.getDefaultBucket() orelse return false;

        // Step 4: Return whether mode is persistent
        return bucket.mode == .persistent;
    }

    /// Request persistent storage for this origin
    /// https://storage.spec.whatwg.org/#dom-storagemanager-persist
    ///
    /// This method requests that the user agent persist the origin's storage,
    /// protecting it from automatic eviction under storage pressure.
    ///
    /// The user agent MAY:
    /// - Automatically grant the request
    /// - Prompt the user for permission
    /// - Deny the request based on origin characteristics
    ///
    /// Algorithm:
    /// 1. Let shelf be the result of obtaining a local storage shelf for origin
    /// 2. If shelf is failure, return false
    /// 3. Let bucket be shelf's bucket map["default"]
    /// 4. If bucket's mode is "persistent", return true
    /// 5. Let permission be the result of requesting permission
    /// 6. If permission is "granted":
    ///    a. Set bucket's mode to "persistent"
    ///    b. Return true
    /// 7. Return false
    pub fn persist(self: *Self) !bool {
        // Step 1: Obtain the local storage shelf
        const shelf = try standard.obtainLocalStorageShelf(
            self.allocator,
            self.origin,
        ) orelse return false;

        // Step 2-3: Get the default bucket
        const bucket = shelf.getDefaultBucket() orelse return false;

        // Step 4: Already persistent
        if (bucket.mode == .persistent) {
            return true;
        }

        // Step 5: Request permission from user
        // The permission callback should be set by the embedder
        const granted = permission_callback(self.origin);

        // Step 6: If granted, update mode
        if (granted) {
            bucket.mode = .persistent;
            return true;
        }

        // Step 7: Permission denied
        return false;
    }

    /// Get storage estimate for this origin
    /// https://storage.spec.whatwg.org/#dom-storagemanager-estimate
    ///
    /// Returns a StorageEstimate containing:
    /// - usage: The approximate number of bytes used by the origin
    /// - quota: The approximate number of bytes available to the origin
    ///
    /// Note: These values are intentionally imprecise to prevent fingerprinting
    /// and avoid revealing exact disk usage.
    ///
    /// Algorithm:
    /// 1. Let shelf be the result of obtaining a local storage shelf for origin
    /// 2. If shelf is failure, return failure
    /// 3. Let usage be shelf's estimated usage
    /// 4. Let quota be shelf's quota
    /// 5. Return StorageEstimate { usage, quota }
    pub fn estimate(self: *Self) !?standard.StorageEstimate {
        return standard.getStorageEstimate(self.allocator, self.origin);
    }

    /// Get the navigator.storage object for a given origin
    /// This is a convenience method for creating a StorageManager
    /// that matches the NavigatorStorage mixin pattern
    pub fn forNavigator(allocator: std.mem.Allocator, origin: []const u8) !Self {
        return init(allocator, origin);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "StorageManager - init and deinit" {
    const allocator = std.testing.allocator;

    var manager = try StorageManager.init(allocator, "https://example.com");
    defer manager.deinit();

    try std.testing.expectEqualStrings("https://example.com", manager.origin);
}

test "StorageManager - persisted returns false by default" {
    const allocator = std.testing.allocator;

    // Clean up any existing global shed and ensure we start fresh
    standard.deinitGlobalStorageShed(allocator);
    defer standard.deinitGlobalStorageShed(allocator);

    var manager = try StorageManager.init(allocator, "https://example.com");
    defer manager.deinit();

    // New origins start with best_effort mode (not persisted)
    const is_persisted = try manager.persisted();
    try std.testing.expect(!is_persisted);
}

test "StorageManager - persist without permission returns false" {
    const allocator = std.testing.allocator;

    // Clean up any existing global shed and ensure we start fresh
    standard.deinitGlobalStorageShed(allocator);
    defer standard.deinitGlobalStorageShed(allocator);

    var manager = try StorageManager.init(allocator, "https://example.com");
    defer manager.deinit();

    // Default permission callback denies
    const granted = try manager.persist();
    try std.testing.expect(!granted);
}

test "StorageManager - persist with permission grants persistent storage" {
    const allocator = std.testing.allocator;

    // Clean up any existing global shed and ensure we start fresh
    standard.deinitGlobalStorageShed(allocator);
    defer standard.deinitGlobalStorageShed(allocator);

    // Set up a permission callback that grants
    const old_callback = StorageManager.permission_callback;
    defer StorageManager.setPermissionCallback(old_callback);

    StorageManager.setPermissionCallback(struct {
        fn grant(_: []const u8) bool {
            return true;
        }
    }.grant);

    var manager = try StorageManager.init(allocator, "https://example.com");
    defer manager.deinit();

    // With granting callback, persist should succeed
    const granted = try manager.persist();
    try std.testing.expect(granted);

    // Now persisted should return true
    const is_persisted = try manager.persisted();
    try std.testing.expect(is_persisted);
}

test "StorageManager - estimate returns usage and quota" {
    const allocator = std.testing.allocator;

    // Clean up any existing global shed and ensure we start fresh
    standard.deinitGlobalStorageShed(allocator);
    defer standard.deinitGlobalStorageShed(allocator);

    var manager = try StorageManager.init(allocator, "https://example.com");
    defer manager.deinit();

    // Get estimate
    const est = try manager.estimate();
    try std.testing.expect(est != null);

    // New origin should have 0 usage
    try std.testing.expectEqual(@as(u64, 0), est.?.usage);

    // Quota should be positive
    try std.testing.expect(est.?.quota > 0);
}

test "StorageManager - initBorrowed does not own origin" {
    const allocator = std.testing.allocator;

    const origin = "https://example.com";
    var manager = StorageManager.initBorrowed(allocator, origin);
    defer manager.deinit(); // Should not free origin

    try std.testing.expectEqualStrings(origin, manager.origin);
    try std.testing.expect(!manager.origin_owned);
}
