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
//! const manager = StorageManager.init(allocator, user_agent_storage, "https://example.com");
//! defer manager.deinit();
//!
//! // Check if storage is persisted
//! const is_persisted = try manager.persisted();
//!
//! // Request persistent storage (requires user permission)
//! const granted = try manager.persist(request); // the Browser's permission request (PermissionRequest)
//!
//! // Get storage estimate
//! if (try manager.estimate()) |est| {
//!     std.debug.print("Usage: {} bytes, Quota: {} bytes\n", .{ est.usage, est.quota });
//! }
//! ```

const std = @import("std");
const standard = @import("standard.zig");
const fs = @import("fs");

/// StorageManager interface
/// https://storage.spec.whatwg.org/#storagemanager
pub const StorageManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    /// The user agent's storage - its Browser's (a supplement of its scope),
    /// whose shelves this manager reads and writes. BORROWED: the Browser
    /// outlives every StorageManager of its realms.
    user_agent_storage: *standard.UserAgentStorage,
    /// The origin this StorageManager is associated with
    origin: []const u8,
    /// Owned copy of origin string
    origin_owned: bool,

    /// Storage persist() step 5.1, "requesting permission to use"
    /// "persistent-storage" (Permissions): the CALLER's, per call. In Crane
    /// that answer is the requesting realm's Browser's - its permission store
    /// (src/permissions/browser_store.zig, through BrowserScope) and the
    /// platform protocol's os_permissions `requestPermission` - so it is not
    /// this module's to hold. (It held a process-wide callback that no
    /// embedder ever set, and that answered every Browser alike - lane
    /// hookfreeze2 removed it.)
    pub const PermissionRequest = struct {
        context: ?*anyopaque = null,
        /// Request the permission for `origin`: true when the result is
        /// "granted".
        request: *const fn (context: ?*anyopaque, origin: []const u8) bool,

        /// No permission request is wired to this caller yet: "denied".
        pub const denied: PermissionRequest = .{ .request = &deny };

        fn deny(_: ?*anyopaque, _: []const u8) bool {
            return false;
        }
    };

    /// Initialize a StorageManager for the given origin, in
    /// `user_agent_storage` (its Browser's).
    pub fn init(allocator: std.mem.Allocator, user_agent_storage: *standard.UserAgentStorage, origin: []const u8) !Self {
        const origin_copy = try allocator.dupe(u8, origin);
        return Self{
            .allocator = allocator,
            .user_agent_storage = user_agent_storage,
            .origin = origin_copy,
            .origin_owned = true,
        };
    }

    /// Initialize with a borrowed origin (caller maintains ownership)
    pub fn initBorrowed(allocator: std.mem.Allocator, user_agent_storage: *standard.UserAgentStorage, origin: []const u8) Self {
        return Self{
            .allocator = allocator,
            .user_agent_storage = user_agent_storage,
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
        // The shelf is read under the shed's lock: a worker's manager asks
        // from its own thread.
        self.user_agent_storage.lock();
        defer self.user_agent_storage.unlock();
        // Step 1: Obtain the local storage shelf for this origin
        const shelf = try self.user_agent_storage.obtainShelfLocked(self.origin) orelse return false;

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
    /// Algorithm (Storage, the persist() method steps; the promise is the
    /// binding's):
    /// 3. Let shelf be the result of obtaining a local storage shelf.
    /// 4. If shelf is failure, the promise rejects (here: false).
    /// 5.1. Let permission be the result of requesting permission to use
    ///      "persistent-storage" (`permission`, the caller's).
    /// 5.2. Let bucket be shelf's bucket map["default"].
    /// 5.3. Let persisted be true if bucket's mode is "persistent".
    /// 5.4. If persisted is false and permission is "granted": set bucket's
    ///      mode to "persistent" and persisted to true.
    /// 5.5. Resolve with persisted.
    /// Permission is requested before the mode is read - also for a bucket
    /// already persistent (the code returned before asking until lane
    /// hookfreeze2).
    pub fn persist(self: *Self, permission: PermissionRequest) !bool {
        // The shelf is read and written under the shed's lock (as persisted).
        // The permission request runs under it too: it is the caller's
        // answer, and must not reach the shed again.
        self.user_agent_storage.lock();
        defer self.user_agent_storage.unlock();
        // Step 3: obtain a local storage shelf. Step 4: failure.
        const shelf = try self.user_agent_storage.obtainShelfLocked(self.origin) orelse return false;

        // Step 5.1: request permission to use "persistent-storage".
        const granted = permission.request(permission.context, self.origin);

        // Step 5.2: the default bucket. Its absence is an internal error:
        // persisted is false (5.3's note).
        const bucket = shelf.getDefaultBucket() orelse return false;

        // Step 5.3.
        var persisted = bucket.mode == .persistent;

        // Step 5.4.
        if (!persisted and granted) {
            bucket.mode = .persistent;
            persisted = true;
        }

        // Step 5.5 (the binding resolves its promise with it).
        return persisted;
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
        return standard.getStorageEstimate(self.user_agent_storage, self.origin);
    }

    /// Get the navigator.storage object for a given origin
    /// This is a convenience method for creating a StorageManager
    /// that matches the NavigatorStorage mixin pattern
    pub fn forNavigator(allocator: std.mem.Allocator, user_agent_storage: *standard.UserAgentStorage, origin: []const u8) !Self {
        return init(allocator, user_agent_storage, origin);
    }

    /// Get the root directory of the bucket file system for this origin.
    /// https://fs.spec.whatwg.org/#dom-storagemanager-getdirectory
    ///
    /// Returns a FileSystemDirectoryHandle for the origin's bucket file system.
    /// This file system is:
    /// - Origin-private (not visible to user on disk)
    /// - Automatically permission-granted (no prompts)
    /// - Subject to storage quota
    ///
    /// Algorithm:
    /// 1. Let shelf be the result of obtaining a local storage shelf for origin
    /// 2. If shelf is failure, reject with SecurityError
    /// 3. Let bucket be shelf's bucket map["default"]
    /// 4. Let root be bucket's file system root directory
    /// 5. Return a FileSystemDirectoryHandle for root
    pub fn getDirectory(self: *Self) !fs.FileSystemDirectoryHandle {
        // Step 1-3: Get the bucket file system for this origin
        const bucket_fs = try standard.getBucketFileSystem(self.user_agent_storage, self.origin);

        // Step 4-5: Return handle to root directory
        return bucket_fs.getDirectory();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "StorageManager - init and deinit" {
    const allocator = std.testing.allocator;
    var user_agent_storage = standard.UserAgentStorage.init(allocator);
    defer user_agent_storage.deinit();

    var manager = try StorageManager.init(allocator, &user_agent_storage, "https://example.com");
    defer manager.deinit();

    try std.testing.expectEqualStrings("https://example.com", manager.origin);
}

test "StorageManager - persisted returns false by default" {
    const allocator = std.testing.allocator;

    var user_agent_storage = standard.UserAgentStorage.init(allocator);
    defer user_agent_storage.deinit();

    var manager = try StorageManager.init(allocator, &user_agent_storage, "https://example.com");
    defer manager.deinit();

    // New origins start with best_effort mode (not persisted)
    const is_persisted = try manager.persisted();
    try std.testing.expect(!is_persisted);
}

test "StorageManager - persist without permission returns false" {
    const allocator = std.testing.allocator;

    var user_agent_storage = standard.UserAgentStorage.init(allocator);
    defer user_agent_storage.deinit();

    var manager = try StorageManager.init(allocator, &user_agent_storage, "https://example.com");
    defer manager.deinit();

    // No permission request wired: denied.
    const granted = try manager.persist(.denied);
    try std.testing.expect(!granted);
}

test "StorageManager - persist with permission grants persistent storage" {
    const allocator = std.testing.allocator;

    var user_agent_storage = standard.UserAgentStorage.init(allocator);
    defer user_agent_storage.deinit();

    // A permission request that grants.
    const Grant = struct {
        fn grant(_: ?*anyopaque, _: []const u8) bool {
            return true;
        }
    };

    var manager = try StorageManager.init(allocator, &user_agent_storage, "https://example.com");
    defer manager.deinit();

    // Granted: persist succeeds.
    const granted = try manager.persist(.{ .request = &Grant.grant });
    try std.testing.expect(granted);

    // Now persisted should return true
    const is_persisted = try manager.persisted();
    try std.testing.expect(is_persisted);
}

test "StorageManager - persist requests permission first, even for a bucket already persistent (Storage persist() step 5.1)" {
    const allocator = std.testing.allocator;

    var user_agent_storage = standard.UserAgentStorage.init(allocator);
    defer user_agent_storage.deinit();

    const Asked = struct {
        fn grant(context: ?*anyopaque, _: []const u8) bool {
            const count: *usize = @ptrCast(@alignCast(context.?));
            count.* += 1;
            return true;
        }
    };
    var asked: usize = 0;
    const request: StorageManager.PermissionRequest = .{ .context = &asked, .request = &Asked.grant };

    var manager = try StorageManager.init(allocator, &user_agent_storage, "https://example.com");
    defer manager.deinit();

    try std.testing.expect(try manager.persist(request));
    try std.testing.expectEqual(@as(usize, 1), asked);
    // Already persistent: step 5.1 still requests permission before step
    // 5.3 reads the bucket's mode, and persisted stays true.
    try std.testing.expect(try manager.persist(request));
    try std.testing.expectEqual(@as(usize, 2), asked);
    // A denial does not take persistence away (5.4 only ever sets it).
    try std.testing.expect(try manager.persist(.denied));
}

test "StorageManager - estimate returns usage and quota" {
    const allocator = std.testing.allocator;

    var user_agent_storage = standard.UserAgentStorage.init(allocator);
    defer user_agent_storage.deinit();

    var manager = try StorageManager.init(allocator, &user_agent_storage, "https://example.com");
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
    var user_agent_storage = standard.UserAgentStorage.init(allocator);
    defer user_agent_storage.deinit();
    var manager = StorageManager.initBorrowed(allocator, &user_agent_storage, origin);
    defer manager.deinit(); // Should not free origin

    try std.testing.expectEqualStrings(origin, manager.origin);
    try std.testing.expect(!manager.origin_owned);
}
